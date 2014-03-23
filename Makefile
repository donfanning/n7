

n7 = bin/n7
src_files = $(addprefix src/,build n7.main *.sh)

$(n7): $(src_files)
	$(addprefix src/,build n7.main) > $@; chmod +x $@


clean:
	rm -f $(n7)
