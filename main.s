.global main

usage_format: .asciz "usage: %s <filename>\n"

# Our main function will be called with two arguments:
# main(int argc, char * * argv)
#   - argc holds the number of command line arguments.
#   - argv holds the address of an array of strings.
#
# Keep in mind that strings themselves are the address of their first character.
# So argv[0] holds the address of the first character of the first argument
# and argv[1] holds the address of the first character of the second argument.
#
# You always get a free argument that holds the name used to invoke the executable.
# This argument is always argv[0] and it counts for argc (which is thus always 1 or greater).
# If you are expecting exactly one additional command line argument,
# argc should be 2 and the argument in question will be at argv[1].
main:
	pushq %rbp
	movq %rsp, %rbp
	subq $16, %rsp

	# Make sure we got one argument.
	# The first argument is always the name of our program, so we want a second argument.
	cmp $2, %rdi
	jne wrong_argc

	# Read the file with the brainfuck code.
	# 8(%rsi) is argv[1], the path of the file we should read.
	# See read_file.s for details on the read_file subroutine.
	movq 8(%rsi), %rdi
	leaq -8(%rbp), %rsi
	call read_file
	test %rax, %rax
	jz failed
	movq %rax, -16(%rbp)

	# Now we're calling you.
	# Good luck.
	movq %rax, %rdi
	call brainfuck

	# Free the buffer allocated by read_file.
	movq -16(%rbp), %rdi
	call free

	# Return success.
	# Unless of course you made us segfault?
	mov $0, %rax
	movq %rbp, %rsp
	popq %rbp
	ret

wrong_argc:
	movq $usage_format, %rdi
	movq (%rsi), %rsi # %rsi still hold argv up to this point
	call printf

failed:
	movq $1, %rax

	movq %rbp, %rsp
	popq %rbp
	ret
