# Z_Init
Command Line Tool used to copy from and store common template projects for ease of rapid prototyping.

*Currently Supports Windows and Linux, uncertain about Mac*

---






To use download the repo and run 
```
zig build-exe -OReleaseSmall z_init.zig
```

Then add the folder that containes the outputted file to your path. (Windows Path, or Bash RC). Then you can use the program from anywhere inside your terminal. (Close and reopen the terminal if it isn't working) The folder that contains the exe will need to have a subfolder called "FolderTemplates". This is so the program has a good place to store the template-files/folders.
