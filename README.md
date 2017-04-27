# Simple calculator demo

## Description

This Genero BDL demo implements a calculator which can evaluate simple
arithmetical expressions using basic math functions and user variables.

The code is based on the "shunting-yard" algorithm.

![Simple calculator demo (GDC)](https://github.com/FourjsGenero/ex_formula/raw/master/docs/formula-screen-001.png)

## Prerequisites

* Genero BDL 3.10+
* Genero Desktop Client 3.10+
* GNU Make

## Compilation from command line

1. make clean all
2. make run

## Compilation in Genero Studio

1. Load the formula.4pw project
2. Build the project

## Usage

1. Start the program
2. Enter a formula in the textedit field
3. Hit the [Compute] button to make the calculation
4. Define your variables in the right panel
5. Use the variables in a formula

## Programmer's reference

### No-regression tests

The libformula.4gl code implements non-regression tests that can be
enabled when compiling with the -D TEST option, try:

``
make test
``

### libformula.4gl

APIs:

* initialize(): Module initialization function to be called before others.
* finalize(): Module finalization function to be called when lib is no longer needed.
* setVariable(name STRING,value DECIMAL(32)): Set a variable.
* getVariable(name STRING) RETURNS DECIMAL(32): Get the value of a variable.
* clearVariable(name STRING): Get the value of a variable.
* clearVariables(): Clear all user variables (predefined constants like Pi are kept)
* getVariableList(varlist DYNAMIC ARRAY OF RECORD): Fills the array passed as parameter with the current list defined variables.
* evaluate(expr STRING): Evaluate the expressions passed as parameter. This function returns a status and the computed value.
* getErrorMessage(num SMALLINT): Returns a clear error message from the status of evaluate().

The status returned by evaluate() can take following values:
- EE_SYNTAX_ERROR
- EE_INVALID_NUMBER
- EE_INVALID_FUNCTION
- EE_INVALID_OPERATOR
- EE_INVALID_OPERANDS
- EE_PARENTHESES_MISMATCH
- EE_UNDEFINED_VARIABLE
- EE_COMP_STACK_ERROR
- EE_DIVISION_BY_ZERO


### liblexer.4gl

WARNINGS:
* Supports any single-byte charset (like ISO88591) or UTF-8 with FGL_LENGTH_SEMANTICS=CHAR
* Identifiers can only be ASCII based ([_a-zA-Z][0-9_a-zA-Z])

APIs:

* initialize(): Module initialization function to be called before others.
* finalize(): Module finalization function to be called when lib is no longer needed.
* getNextToken(buf base.StringBuffer, pos INTEGER, ib BOOLEAN): Get the next token starting from pos.
 - When last parameter is TRUE, does not consider blanks as tokens.
 - Then function returns the tokenid, the next position and the token value.
 - If SL_TOKID_END is returned, the scan is finished.

Possible token ids are:

- SL_TOKID_END
- SL_TOKID_BLANK
- SL_TOKID_IDENT
- SL_TOKID_STRING
- SL_TOKID_NUMBER
- SL_TOKID_OTHER
- SL_TOKID_INV_STRING
- SL_TOKID_INV_NUMBER
- SL_TOKID_INV_IDENT
- SL_TOKID_INV_BLANK


## Bug fixes:

