To quickly convert C++ headers into a module, follow the method below:

```cpp
// lib.hpp
#ifndef LIB_HPP
#define LIB_HPP
#include <system_headers>
#include <cppstd_headers>

#include "impl1.h"
#include "impl2.h"

namespace lib
{
  struct foo {};
  void bar() {};
}
#endif
```

```cpp
// lib_module.cppm
module;
#include "lib.hpp"
export module lib;

export namespace lib
{
  using lib::foo;
  using lib::bar;
}
```

However, this is not ideal because the `std` module is not used. C++ standard library headers are often the biggest factor affecting compilation speed, so if we could remove the includes and use `import std;` instead, that would be optimal.

At present, the solution to achieve this is:

```cpp
// lib_module.cppm
module;

#include <system_headers>
#include <cassert> // NB
#include "clear_all_cpp_std_headers.h"

export module lib;
import std;

extern "C++"
{
#include "lib.hpp"
}
export namespace lib
{
  using lib::foo;
  using lib::bar;
}

```

Here are several articles introducing C++ modules that are well worth reading, listed in order from simpler to more advanced:

* C++ Modules: [en](https://blog.bizwen.com/blog/2026/05/05/Cpp-Module/) [zh](https://blog.bizwen.com/blog/2022/08/28/Cpp-Module/)
* C++ Modules In Depth: [en](https://blog.bizwen.com/blog/2026/06/22/Modules-In-Depth-en/) [zh](https://blog.bizwen.com/blog/2026/06/22/Modules-In-Depth/)
* C++20 Modules: Practical Insights, Status and TODOs: [en](https://chuanqixu9.github.io/c++/2025/08/14/C++20-Modules.en.html) [zh](https://chuanqixu9.github.io/c++/2025/08/14/C++20-Modules.html)
* C++20 Modules: Best Practices from a User's Perspective: [en](https://chuanqixu9.github.io/c++/2025/12/30/C++20-Modules-Best-Practices.en.html) [zh](https://chuanqixu9.github.io/c++/2025/12/30/C++20-Modules-Best-Practices.html)
