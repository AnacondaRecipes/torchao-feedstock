@rem CPU-only Windows build: pure Python mode, no C++ compilation.
SET VERSION_SUFFIX=
SET USE_CPP=0
SET BUILD_TORCHAO_EXPERIMENTAL=0

%PYTHON% -m pip install . -vv --no-deps --no-build-isolation
IF %ERRORLEVEL% NEQ 0 EXIT /B %ERRORLEVEL%
