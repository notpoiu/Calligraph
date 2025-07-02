@ECHO OFF
darklua.exe process -c ".\config.json" -v "main.luau" "compiled\Calligraph.luau"
ECHO 	- Release compiled!