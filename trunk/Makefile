# Makefile
# vala project
#

# name of your project/program
PROGRAM = valauo


# for most cases the following two are the only you'll need to change
# add your source files here
SRC = \
	src/Main.vala

# add your used packges here
PKGS =

# vala compiler
VALAC = valac

# compiler options for a debug build
VALACOPTS = -g

# set this as root makefile for Valencia
BUILD_ROOT = 1

# the 'all' target build a debug build
all:
	@$(VALAC) $(VALACOPTS) $(SRC) -o $(PROGRAM) $(PKGS)

# the 'release' target builds a release build
# you might want to disabled asserts also
release: clean
	@$(VALAC) -X -O2 $(SRC) -o main_release $(PKGS)

# clean all built files
clean:
	@rm -v -fr *~ *.c $(PROGRAM)