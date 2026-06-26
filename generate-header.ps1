<#
.SYNOPSIS
    Extracts the first #ifndef macro from GCC and LLVM standard library header files to generate a unified guard macro definition file.
    For STL, this is not necessary; a fixed #define _STL_COMPILER_PREPROCESSOR 0 can be used.
    Skips cassert because the standard requires it not to have include guards.

.DESCRIPTION
    This script generates a file used to disable standard library headers, supporting libstdc++, libc++, and STL.
    After including the generated header file with #include, all subsequent standard library headers (except cassert) will expand to empty files.

.PARAMETER Token
    Required GitHub personal access token for calling the GitHub API.
    The token requires 'public_repo' permission.

.PARAMETER OutputFile
    Required output file path. The script writes the generated content to this file.

.EXAMPLE
    .\generate_guards.ps1 -Token "ghp_xxxxxxxxxxxx" -OutputFile "output.h"

.LINK
    Get GitHub Token: https://github.com/settings/tokens
    Check 'public_repo' scope.
#>

param(
    [Parameter(Mandatory=$true, HelpMessage="GitHub personal access token (requires public_repo permission)")]
    [string]$Token,

    [Parameter(Mandatory=$true, HelpMessage="Output file path")]
    [string]$OutputFile
)

# GitHub API public headers
$headers = @{
    "Accept" = "application/vnd.github.v3+json"
    "Authorization" = "token $Token"
}

# Get the latest commit hash from a repository
function Get-LatestCommitHash {
    param([string]$repoPath)
    $url = "https://api.github.com/repos/$repoPath/commits/HEAD"
    $resp = Invoke-RestMethod -Uri $url -Headers $headers
    return $resp.sha
}

# Get commit hashes for both repositories
$gccRepo = "gcc-mirror/gcc"
$llvmRepo = "llvm/llvm-project"
$gccCommit = Get-LatestCommitHash -repoPath $gccRepo
$llvmCommit = Get-LatestCommitHash -repoPath $llvmRepo

# Build information for both directories
$dirs = @(
    @{
        # libstdc++ c_global directory (C++ wrappers for C library headers)
        ApiUrl = "https://api.github.com/repos/$gccRepo/contents/libstdc++-v3/include/c_global?ref=$gccCommit"
        IsGcc = $true
        Commit = $gccCommit
        Repo = $gccRepo
    },
    @{
        ApiUrl = "https://api.github.com/repos/$gccRepo/contents/libstdc++-v3/include/std?ref=$gccCommit"
        IsGcc = $true
        Commit = $gccCommit
        Repo = $gccRepo
    },
    @{
        ApiUrl = "https://api.github.com/repos/$llvmRepo/contents/libcxx/include?ref=$llvmCommit"
        IsGcc = $false
        Commit = $llvmCommit
        Repo = $llvmRepo
    }
)

$timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss UTC")

# Output file lines collection
$outputLines = [System.Collections.Generic.List[string]]::new()

# Add comment block (outside the guard)
$outputLines.Add("/*")
$outputLines.Add(" * Generated at: $timestamp")
$outputLines.Add(" * GCC commit: $gccCommit")
$outputLines.Add(" * LLVM commit: $llvmCommit")
$outputLines.Add(" */")
$outputLines.Add("")

# First collect all eligible file names (for unified progress display)
$allFiles = [System.Collections.Generic.List[PSObject]]::new()

foreach ($dir in $dirs) {
    $response = Invoke-RestMethod -Uri $dir.ApiUrl -Headers $headers

    # Filter files: type is file, doesn't start with underscore, doesn't contain a dot, and name is not cassert
    $files = $response | Where-Object { 
        $_.type -eq "file" -and 
        $_.name -notlike '_*' -and 
        $_.name -notlike '*.*' -and
        $_.name -ne 'cassert'
    }

    # Add file information to the global list, also record the repository label
    foreach ($f in $files) {
        $allFiles.Add([PSCustomObject]@{
            Name = $f.name
            DownloadUrl = $f.download_url
            IsGcc = $dir.IsGcc
        })
    }
}

$total = $allFiles.Count

Write-Host "Found $total eligible files..."

# Iterate through all files and process them
$index = 0
foreach ($file in $allFiles) {
    $index++
    # Add repository label to distinguish between same-named GCC and LLVM files
    $repoLabel = if ($file.IsGcc) { "[libstdc++]" } else { "[libc++]" }
    Write-Host "$repoLabel $($file.Name) ($index/$total)"

    $content = Invoke-RestMethod -Uri $file.DownloadUrl -Headers $headers

    $lines = $content -split "`n"
    $found = $false
    foreach ($line in $lines) {
        if ($line -match '^\s*#ifndef\s+([A-Za-z_]\w*)') {
            $macro = $matches[1]
            if ($file.IsGcc) {
                $outputLines.Add("#ifndef $macro")
                $outputLines.Add("#define $macro 1")
                $outputLines.Add("#endif")
            } else {
                $outputLines.Add("#ifndef $macro")
                $outputLines.Add("#define $macro")
                $outputLines.Add("#endif")
            }
            $found = $true
            break
        }
    }
    if (-not $found) {
        throw "#ifndef not found in file $repoLabel $($file.Name)"
    }
}

# STL
Write-Host "[STL] Done"
$outputLines.Add("#ifdef _STL_COMPILER_PREPROCESSOR")
$outputLines.Add("#undef _STL_COMPILER_PREPROCESSOR")
$outputLines.Add("#endif")
$outputLines.Add("#define _STL_COMPILER_PREPROCESSOR 0")

[System.IO.File]::WriteAllLines($OutputFile, $outputLines, [System.Text.UTF8Encoding]::new($false))

Write-Host "Processed $total files total, output written to $OutputFile"