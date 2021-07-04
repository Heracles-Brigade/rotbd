build-win:
	if not exist "dist" mkdir "dist"
	del ".\dist\*" /Q
	cmd "/C for /R .\src %F in (*) do copy /Y %F ".\dist\""

build-linux:
	rm -r ./dist/*
	find ./src/ -not -name '*.bin' -type f -exec cp {} ./dist \;
