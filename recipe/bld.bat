@rem CPU-only Windows build: pure Python mode, no C++ compilation.
SET USE_CPP=0
SET BUILD_TORCHAO_EXPERIMENTAL=0

@rem setup.py appends a "+git" suffix when VERSION_SUFFIX is unset, and cmd's
@rem "SET VERSION_SUFFIX=" unsets it. Launch pip from Python with an empty value.
%PYTHON% -c "import os, subprocess, sys; env = dict(os.environ, VERSION_SUFFIX=''); sys.exit(subprocess.call([sys.executable, '-m', 'pip', 'install', '.', '-vv', '--no-deps', '--no-build-isolation'], env=env))"
IF %ERRORLEVEL% NEQ 0 EXIT /B %ERRORLEVEL%

@rem setup.py's find_packages() also installs upstream's top-level test suite; drop it.
@rem Resolve site-packages from Python: py3.15 (nt_conda scheme) differs from SP_DIR.
for /f "usebackq delims=" %%i in (`%PYTHON% -c "import sysconfig; print(sysconfig.get_path('purelib'))"`) do set "PURELIB=%%i"
IF EXIST "%PURELIB%\test" rmdir /s /q "%PURELIB%\test"
IF %ERRORLEVEL% NEQ 0 EXIT /B %ERRORLEVEL%
