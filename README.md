# x86-64 Brainfuck Interpreter

A fast Brainfuck interpreter written in x86-64 assembly using GNU assembler AT&T syntax.

I originally built this as part of a university project, but I kept working on it beyond the basic requirements because I wanted to see how far I could push the performance while still keeping it an actual **interpreter**.

The main goal was basically:

> make as many Brainfuck operations disappear before runtime as possible

## What it does

- Written in x86-64 assembly
- Uses a direct-threaded interpreter design
- Collapses repeated `+` / `-` operations
- Collapses repeated `>` / `<` operations
- Optimises common Brainfuck loop patterns
- Includes linear-loop optimisation
- Uses buffered output to reduce syscall overhead
- Uses a 30,000-byte Brainfuck tape
- Focuses on runtime efficiency while staying interpreter-based

## Files

- `brainfuck.s`  
  The actual interpreter and optimisation logic.

- `main.s`  
  Handles the command-line argument and passes the Brainfuck source to the interpreter.

- `read_file.s`  
  Reads the Brainfuck file into memory.

- `Makefile`  
  Builds the project.

- `test.bf`  
  Main benchmark / larger test program.

How it works
The interpreter first scans the Brainfuck source and reduces repeated operations and certain loop patterns into larger internal operations.
Those operations are then executed by fixed assembly handlers.
So instead of interpreting every single Brainfuck character literally one by one, the interpreter tries to reduce unnecessary work before execution.
Repeated arithmetic, pointer movement, and some predictable loops can therefore be handled much more efficiently.
The important part is that the runtime still executes a predefined interpreter. No x86 code is generated dynamically.


***Academic Integrity
This repository is public for learning, portfolio, and discussion purposes.
Do not use this code, or substantial parts of it, in your own university or academic submissions.
If you are doing the same or a similar assignment, you may not copy this implementation and submit it as your own work.
Feel free to study the ideas, understand the approach, compare design choices, or learn from the optimisation techniques, but your submitted solution must be your own.***
