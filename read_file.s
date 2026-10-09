.global read_file

# Taken from <stdio.h>
.equ SEEK_SET,  0
.equ SEEK_CUR,  1
.equ SEEK_END,  2
.equ EOF,      -1

file_mode: .asciz "r"

# char * read_file(char const * filename, int * read_bytes)
#
# Read the contents of a file into a newly allocated memory buffer.
# The address of the allocated memory buffer is returned and
# read_bytes is set to the number of bytes read.
#
# A null byte is appended after the file contents, but you are
# encouraged to use read_bytes instead of treating the file contents
# as a null terminated string.
#
# Technically, you should call free() on the returned pointer once
# you are done with the buffer, but you are forgiven if you do not.
read_file:
	pushq %rbp
	movq %rsp, %rbp

	# internal stack usage:
	#  -8(%rbp) saved read_bytes pointer
	# -16(%rbp) FILE pointer
	# -24(%rbp) file size
	# -32(%rbp) address of allocated buffer
	subq $32, %rsp

	# Save the read_bytes pointer.
	movq %rsi, -8(%rbp)

	# Open file for reading.
	movq $file_mode, %rsi
	call fopen
	testq %rax, %rax
	jz _read_file_open_failed
	movq %rax, -16(%rbp)

	# Seek to end of file.
	movq %rax, %rdi
	movq $0, %rsi
	movq $SEEK_END, %rdx
	call fseek
	testq %rax, %rax
	jnz _read_file_seek_failed

	# Get current position in file (length of file).
	movq -16(%rbp), %rdi
	call ftell
	cmpq $EOF, %rax
	je _read_file_tell_failed
	movq %rax, -24(%rbp)

	# Seek back to start.
	movq -16(%rbp), %rdi
	movq $0, %rsi
	movq $SEEK_SET, %rdx
	call fseek
	testq %rax, %rax
	jnz _read_file_seek_failed

	# Allocate memory and store pointer.
	# Allocate file_size + 1 for a trailing null byte.
	movq -24(%rbp), %rdi
	incq %rdi
	call malloc
	test %rax, %rax
	jz _read_file_malloc_failed
	movq %rax, -32(%rbp)

	# Read file contents.
	movq %rax, %rdi
	movq $1, %rsi
	movq -24(%rbp), %rdx
	movq -16(%rbp), %rcx
	call fread
	movq -8(%rbp), %rdi
	movq %rax, (%rdi)

	# Add a trailing null byte, just in case.
	movq -32(%rbp), %rdi
	movb $0, (%rdi, %rax)

	# Close file descriptor
	movq -16(%rbp), %rdi
	call fclose

	# Return address of allocated buffer.
	movq -32(%rbp), %rax
	movq %rbp, %rsp
	popq %rbp
	ret

_read_file_malloc_failed:
_read_file_tell_failed:
_read_file_seek_failed:
	# Close file descriptor
	movq -16(%rbp), %rdi
	call fclose

_read_file_open_failed:
	# Set read_bytes to 0 and return null pointer.
	movq -8(%rbp), %rax
	movq $0, (%rax)
	movq $0, %rax
	movq %rbp, %rsp
	popq %rbp
	ret
