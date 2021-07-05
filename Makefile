build-win:
	if not exist "dist" mkdir "dist"
	del ".\dist\*" /Q
	cmd /C for /R .\src %F in (*) do xcopy "%F" ".\dist" /Y /EXCLUDE:no_dist.txt
	if not exist "deps" mkdir "deps"
	if not exist "deps\lua-5.1.4_Win32_dll12_lib.zip" curl -L "https://sourceforge.net/projects/luabinaries/files/5.1.4/Windows%20Libraries/lua-5.1.4_Win32_dll12_lib.zip/download" --output ".\deps\lua-5.1.4_Win32_dll12_lib.zip"
	pushd dist
	tar -xf "..\deps\lua-5.1.4_Win32_dll12_lib.zip" "lua5.1.dll"
	popd

build-linux:
	rm -r ./dist/*
	find ./src/ -not -name '*.bin' -type f -exec cp {} ./dist \;
