#build-win:
#	cmd "/C for /R .\src %F in (*) do copy /Y %F .\dist"
#build-linux:
#	rm -r ./dist/*
#	find ./src/ -not -name '*.bin' -type f -exec cp {} ./dist \;


mkdir ./dist
for filename in src/*
do
  	if
			[$filename == "src/*.bin"]
		then
			null
		else
			cp -r $filename dist/
		fi
done
