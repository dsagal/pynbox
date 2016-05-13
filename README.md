Python NativeClient Sandbox (pynbox)
====================================

The project helps build a version of Python that runs
in NaCl (NativeClient) sandbox. Most OS operations are unavailable, and access
to the filesystem is limited to a specified directory (similar to chroot).

Security is a major focus of NativeClient. It allows safely executing untrusted code, including the Python interpreter, and all Python code running in it, including native Python modules.

This project combines existing pieces to make this easy to set up.

Quick Start
-----------
```bash
./build.sh
```
This fetches and builds the necessary software, and populates the `./build/` directory, including `./build/sandbox_root/`, which serves as the filesystem root within the sandbox.

```bash
./pynbox -c 'print "Hello world"'
./pynbox test/test_nacl.py
./sandbox_run test/test_hello.nexe
```
Note that to run any python program, that program and all the modules it requires must be placed somewhere under `./build/sandbox_root/`.

Background
----------

[NativeClient](https://developer.chrome.com/native-client) (or NaCl, and a
variant called PNaCl) is a sandbox for running native code in the Google Chrome
browser. The approach involves building the C or C++ code using NaCl suite of
tools (compiler, linker, etc) which produce binaries that verifiably access
only certain APIs (not OS directly), and then running them in an environment (typically
Chrome browser) which provides the necessary APIs.

The NaCl project is developed by Google, but is [open
source](http://www.chromium.org/nativeclient), as part of the Chromium project
(the open-source version of Google Chrome).

There are pretty good resources for building native apps using NaCl to run in
Chrome. What's not common is to run NaCl sandbox without Chrome. The sandbox
comes with a tool for just that, `sel_ldr` (for Secure ELF Loader). It's no longer
used by Chrome itself, so is less well documented, and less well supported and
maintained.

NativeClient project includes a set of ports, known as
[webports](https://chromium.googlesource.com/webports/) which are software
packages that have been made to build under NaCl to run in Chrome.

One of the ports is
[Python](https://chromium.googlesource.com/webports/+/pepper_47/ports/python/README.nacl),
which makes Python interactive shell work under Chrome. It can also run under
`sel_ldr`.

The `sel_ldr` runner can enable access to the filesystem, including a
restricted mode when it limits access to a given directory (similarly to
chroot). If populated with all the modules and libraries that Python need, this
offers a way to run Python with that directory as the
filesystem root.

What\'s included
----------------

`./build.sh` script takes care of fetching the needed software, patching what's
needed, building, and installing files. The script's code is the primary
documentation. The script supports some options, available using `./build.sh
-h`.

Some tests are included and are run by `build.sh`.

The software it includes is `depot_tools`, `nacl_sdk`, `webports` (specifically
Python and its dependencies), and optionally NaCl source code.

The output it produces is in the `./build/` directory. It also prepares
`./build/sandbox_root/` to serve as the filesystem root for the sandbox. A
separate short script `./sandbox_run` helps run binaries in the sandbox, and `./pynbox` runs the
Python interpreter in the sandbox.
