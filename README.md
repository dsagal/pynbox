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
This fetches and builds the necessary software, and populates the `./build/` directory, including `./build/root/`, which serves as the filesystem root within the sandbox.

```bash
./build/run python -c 'print "Hello world"'
./build/run python test/test_nacl.py
./build/run test/test_hello.nexe
```
Note that to run any python program, that program and all the modules it requires must be placed somewhere under `./build/root/`.

```bash
./build.sh install lxml
```
Build and install python package `lxml`.

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

You can build a webport of a python package and install into the `./build/` directory using `./build.sh install <package>`, e.g.
```bash
./build.sh install lxml
```

The software it includes is `depot_tools`, `nacl_sdk`, `webports` (specifically
Python and its dependencies), and optionally NaCl source code.

The output it produces is in the `./build/` directory. It also prepares
`./build/root/` to serve as the filesystem root for the sandbox. A
separate short script `./build/run` helps run binaries in the sandbox, with `./build/run python`
running the Python interpreter in the sandbox.

Notes
-----
NativeClient encompasses PNaCl (portable native client) and just NaCl. These differ in toolchains used to build code, and produce .pexe and .nexe files respectively. The idea is that .nexe is architecture-specific, and .pexe is more portable: it can be translated to a suitable .nexe file on the fly.

There is a hitch, however: shared libraries are only supported by the glibc toolchain which builds architecture-specific .nexe files directly. We need shared libraries, in particular, to allow Python to load C extension modules.

Loading shared libraries uses "libdl.so" library. This library isn't part of NativeClient source. It is downloaded as part of an architecture specific tgz archive (for each architecture). It seems to have some bugs (or super-weird behavior), in particular opening "/lib/foo" translates to "/foo", while "/./lib/foo" works. This is special for the "/lib" path, so we avoid it by putting libraries under "/usr/lib".
