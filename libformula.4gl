-- Features:
-- Case sensitive! sin()!=SIN(), Pi!=pi, ...
-- Numeric variables only, cannot be NULL
-- DBMONEY/DBFORMAT independent

IMPORT util
IMPORT FGL liblexer

PUBLIC CONSTANT EE_SYNTAX_ERROR         = -999
PUBLIC CONSTANT EE_INVALID_NUMBER       = -998
PUBLIC CONSTANT EE_INVALID_FUNCTION     = -997
PUBLIC CONSTANT EE_INVALID_OPERATOR     = -996
PUBLIC CONSTANT EE_INVALID_OPERANDS     = -995
PUBLIC CONSTANT EE_PARENTHESES_MISMATCH = -994
PUBLIC CONSTANT EE_UNDEFINED_VARIABLE   = -993
PUBLIC CONSTANT EE_COMP_STACK_ERROR     = -992
PUBLIC CONSTANT EE_DIVISION_BY_ZERO     = -991
PUBLIC CONSTANT EE_OPERATOR_ERROR       = -990
PUBLIC CONSTANT EE_OVERFLOW_ERROR       = -989
PUBLIC CONSTANT EE_INVALID_ARGUMENT     = -988

PRIVATE TYPE t_number DECIMAL(32)
PRIVATE TYPE t_elem_type SMALLINT

PRIVATE TYPE t_variable RECORD
               name STRING,
               value t_number
        END RECORD
PUBLIC TYPE t_varlist DYNAMIC ARRAY OF t_variable
PRIVATE DEFINE vars t_varlist

PRIVATE CONSTANT ET_OPER_EXP       = 101
PRIVATE CONSTANT ET_OPER_ADD       = 102
PRIVATE CONSTANT ET_OPER_SUB       = 103
PRIVATE CONSTANT ET_OPER_DIV       = 104
PRIVATE CONSTANT ET_OPER_MUL       = 105
PRIVATE CONSTANT ET_OPER_UNA_MIN   = 106
PRIVATE CONSTANT ET_OPER_UNA_PLS   = 107
PRIVATE CONSTANT ET_OPER_EQL       = 108
PRIVATE CONSTANT ET_OPER_NEQ       = 109
PRIVATE CONSTANT ET_OPER_GRE       = 110
PRIVATE CONSTANT ET_OPER_GRE_EQL   = 111
PRIVATE CONSTANT ET_OPER_LOW       = 112
PRIVATE CONSTANT ET_OPER_LOW_EQL   = 113
PRIVATE CONSTANT ET_OPER_AND       = 114
PRIVATE CONSTANT ET_OPER_OR        = 115
PRIVATE CONSTANT ET_OPER_NOT       = 116
PRIVATE CONSTANT ET_LEFT_BRACE     = 201
PRIVATE CONSTANT ET_RIGHT_BRACE    = 202
PRIVATE CONSTANT ET_COMMA          = 301
PRIVATE CONSTANT ET_FUNCTION       = 401
PRIVATE CONSTANT ET_VALUE          = 501

PRIVATE CONSTANT FN_SIN  = "sin"
PRIVATE CONSTANT FN_ASIN = "asin"
PRIVATE CONSTANT FN_COS  = "cos"
PRIVATE CONSTANT FN_ACOS = "acos"
PRIVATE CONSTANT FN_TAN  = "tan"
PRIVATE CONSTANT FN_ATAN = "atan"
PRIVATE CONSTANT FN_MIN  = "min"
PRIVATE CONSTANT FN_MAX  = "max"
PRIVATE CONSTANT FN_SQRT = "sqrt"
PRIVATE CONSTANT FN_EXP  = "exp"
PRIVATE CONSTANT FN_LOGN = "logn"
PRIVATE CONSTANT FN_MOD  = "mod"
PRIVATE CONSTANT FN_RAND = "rand"
PRIVATE CONSTANT FN_DEG  = "deg"
PRIVATE CONSTANT FN_RAD  = "rad"
PRIVATE CONSTANT FN_IIF  = "iif"
PRIVATE CONSTANT FN_ABS  = "abs"

PRIVATE TYPE t_element RECORD
               type t_elem_type,   -- ET_*
               name STRING,    -- FN_* (type == ET_FUNCTION)
               value t_number  -- (type == ET_VALUE)
        END RECORD

-- Output queue
PRIVATE DEFINE out DYNAMIC ARRAY OF t_element

-- Stack
PRIVATE DEFINE stk DYNAMIC ARRAY OF t_element

PRIVATE DEFINE init_count SMALLINT

&define ASSERT(c) \
    IF NOT (c) THEN \
       DISPLAY SFMT("ASSERT (%1,%2): %3",__FILE__,__LINE__,#c) \
       EXIT PROGRAM 1 \
    END IF

&ifdef TEST

&define TEST_ASSERT(msg, cond) \
  IF NOT (cond) THEN \
     DISPLAY msg, " *** ERROR *** expecting: ",#cond \
     EXIT PROGRAM 1\
  END IF

&define TEST_ASSERT_EVAL(msg, stat, cond) \
  IF NOT (cond) THEN \
     DISPLAY msg, " *** ERROR *** expecting: ",#cond \
     DISPLAY "    ", getErrorMessage(stat) \
     EXIT PROGRAM 1\
  END IF

MAIN
    CALL initialize()
    CALL test_vars()
    CALL test_func()
    CALL test_oper()
    CALL test_output()
    CALL test_stack()
    CALL test_eval()
    CALL finalize()
END MAIN

&endif

PUBLIC FUNCTION getErrorMessage(num)
    DEFINE num SMALLINT
    DEFINE m STRING
    CASE num
      WHEN EE_SYNTAX_ERROR         LET m="Syntax error"
      WHEN EE_INVALID_NUMBER       LET m="Invalid number error"
      WHEN EE_INVALID_FUNCTION     LET m="Invalid function"
      WHEN EE_INVALID_OPERATOR     LET m="Invalid operator"
      WHEN EE_INVALID_OPERANDS     LET m="Invalid operands"
      WHEN EE_PARENTHESES_MISMATCH LET m="Parentheses mismatch"
      WHEN EE_UNDEFINED_VARIABLE   LET m="Undefined variable"
      WHEN EE_COMP_STACK_ERROR     LET m="Computing stack error"
      WHEN EE_DIVISION_BY_ZERO     LET m="Division by zero"
      WHEN EE_OPERATOR_ERROR       LET m="Operator error"
      WHEN EE_OVERFLOW_ERROR       LET m="Overflow error"
      WHEN EE_INVALID_ARGUMENT     LET m="Invalid argument"
   END CASE
   IF num==0 THEN
      RETURN "No error"
   ELSE
      RETURN SFMT("ERROR: (%1) %2",num,m)
   END IF
END FUNCTION

&ifdef TEST

FUNCTION test_vars()
    DEFINE v1 t_number,
           x INTEGER,
           n STRING
    LET v1 = getVariable("test_VAR1")
    TEST_ASSERT("test_vars.01001", v1 IS NULL)
    CALL setVariable("test_VAR1",NULL)
    CALL setVariable("test_VAR2",-999.99)
    LET v1 = getVariable("VAR1")
    TEST_ASSERT("test_vars.01002", v1 IS NULL)
    LET v1 = getVariable("test_VAR2")
    TEST_ASSERT("test_vars.01003", v1 IS NOT NULL AND v1 == -999.99)
    CALL setVariable("test_VAR1",1234.56789)
    LET v1 = getVariable("test_VAR1")
    TEST_ASSERT("test_vars.01004", v1 IS NOT NULL AND v1 == 1234.56789)
    CALL setVariable("test_VAR1",12345678901234567890123456789012)
    LET v1 = getVariable("test_VAR1")
    TEST_ASSERT("test_vars.01005", v1 IS NOT NULL AND v1 == 12345678901234567890123456789012)
    CALL setVariable("test_VAR1",99999999999999999999999999999999)
    LET v1 = getVariable("test_VAR1")
    TEST_ASSERT("test_vars.01006", v1 IS NOT NULL AND v1 == 99999999999999999999999999999999)
    CALL setVariable("test_VAR1",1.234e+99)
    LET v1 = getVariable("test_VAR1")
    TEST_ASSERT("test_vars.01007", v1 IS NOT NULL AND v1 == 1.234e+99)
    CALL setVariable("test_VAR1",-1.234e-99)
    LET v1 = getVariable("test_VAR1")
    TEST_ASSERT("test_vars.01008", v1 IS NOT NULL AND v1 == -1.234e-99)
    FOR x=1 TO 20
        LET n = SFMT("test_VAR%1",x)
        CALL setVariable(n,x)
        LET v1 = getVariable(n)
        TEST_ASSERT(SFMT("test_vars.02%1",(x USING "&&&")), v1 IS NOT NULL AND v1 == x)
    END FOR
END FUNCTION

&endif

#---

PRIVATE FUNCTION lookup_variable(name,auto)
    DEFINE name STRING,
           auto BOOLEAN
    DEFINE x INTEGER
    LET x = vars.search("name", name)
    IF auto AND x<=0 THEN
       LET x = vars.getLength()+1
       LET vars[x].name = name
    END IF
    RETURN x
END FUNCTION

PUBLIC FUNCTION getVariableList(vl)
    DEFINE vl t_varlist
    CALL vars.copyTo( vl )
END FUNCTION

PUBLIC FUNCTION setVariable(name, value)
    DEFINE name STRING,
           value t_number
    DEFINE x INTEGER
    LET x = lookup_variable(name,TRUE)
    LET vars[ x ].value = value
END FUNCTION

PUBLIC FUNCTION clearVariable(name)
    DEFINE name STRING
    DEFINE x INTEGER
    LET x = lookup_variable(name,FALSE)
    IF x>0 THEN
       CALL vars.deleteElement(x)
    END IF
END FUNCTION

PUBLIC FUNCTION getVariable(name)
    DEFINE name STRING
    DEFINE x INTEGER
    LET x = lookup_variable(name,FALSE)
    IF x>0 THEN
       RETURN vars[x].value
    ELSE
       RETURN NULL -- TODO? RETURN 0 (zero) for undefined variables?
    END IF
END FUNCTION

PUBLIC FUNCTION clearVariables()
    CALL vars.clear()
    CALL predefine_constants()
END FUNCTION

#---

&ifdef TEST

FUNCTION test_func()
    DEFINE reg DYNAMIC ARRAY OF t_number,
           r SMALLINT

    CALL reg.clear()
    LET reg[1] = -1 -- not used
    LET reg[2] = -1 -- not used
    LET reg[3] = 1
    LET r = eval_function(FN_SIN, reg)
    TEST_ASSERT("test_func.01001", r==0 AND reg.getLength()==3)
    TEST_ASSERT("test_func.01002", reg[3] IS NOT NULL AND reg[3] == 0.8414709848078965)

    CALL reg.clear()
    LET reg[1] = 1
    LET r = eval_function(FN_ASIN, reg)
    TEST_ASSERT("test_func.01101", r==0 AND reg.getLength()==1)
    TEST_ASSERT("test_func.01102", reg[1] IS NOT NULL AND reg[1] == 1.5707963267948966)

    CALL reg.clear()
    LET reg[1] = 1
    LET r = eval_function(FN_COS, reg)
    TEST_ASSERT("test_func.02001", r==0 AND reg.getLength()==1)
    TEST_ASSERT("test_func.02002", reg[1] IS NOT NULL AND reg[1] == 0.5403023058681398)

    CALL reg.clear()
    LET reg[1] = 0.5
    LET r = eval_function(FN_ACOS, reg)
    TEST_ASSERT("test_func.02101", r==0 AND reg.getLength()==1)
    TEST_ASSERT("test_func.02102", reg[1] IS NOT NULL AND reg[1] == 1.0471975511965979)

    CALL reg.clear()
    LET reg[1] = 2.0
    LET r = eval_function(FN_ACOS, reg)
    TEST_ASSERT("test_func.02101", r==EE_INVALID_ARGUMENT )

    CALL reg.clear()
    LET reg[1] = 5
    LET reg[2] = 10
    LET r = eval_function(FN_MIN, reg)
    TEST_ASSERT("test_func.03001", r==0 AND reg.getLength()==1)
    TEST_ASSERT("test_func.03002", reg[1] IS NOT NULL AND reg[1] == 5)
    CALL reg.clear()
    LET reg[1] = 5
    LET reg[2] = -10
    LET r = eval_function(FN_MIN, reg)
    TEST_ASSERT("test_func.03101", r==0 AND reg.getLength()==1)
    TEST_ASSERT("test_func.03102", reg[1] IS NOT NULL AND reg[1] == -10)

    CALL reg.clear()
    LET reg[1] = 5
    LET reg[2] = 10
    LET r = eval_function(FN_MAX, reg)
    TEST_ASSERT("test_func.04001", r==0 AND reg.getLength()==1)
    TEST_ASSERT("test_func.04002", reg[1] IS NOT NULL AND reg[1] == 10)
    CALL reg.clear()
    LET reg[1] = 5
    LET reg[2] = -10
    LET r = eval_function(FN_MAX, reg)
    TEST_ASSERT("test_func.04101", r==0 AND reg.getLength()==1)
    TEST_ASSERT("test_func.04102", reg[1] IS NOT NULL AND reg[1] == 5)

    CALL reg.clear()
    LET reg[1] = 99999999980000000001.0
    LET r = eval_function(FN_SQRT, reg)
    TEST_ASSERT("test_func.06001", r==0 AND reg.getLength()==1)
    TEST_ASSERT("test_func.06002", reg[1] IS NOT NULL AND reg[1] == 9999999999)

    CALL reg.clear()
    LET reg[1] = 100
    LET r = eval_function(FN_LOGN, reg)
    TEST_ASSERT("test_func.07001", r==0 AND reg.getLength()==1)
    TEST_ASSERT("test_func.07002", reg[1] IS NOT NULL AND reg[1] == 4.605170185988091368035982909405)
    CALL reg.clear()
    LET reg[1] = 1
    LET r = eval_function(FN_LOGN, reg)
    TEST_ASSERT("test_func.07101", r==0 AND reg.getLength()==1)
    TEST_ASSERT("test_func.07102", reg[1] IS NOT NULL AND reg[1] == 0.0)

    CALL reg.clear()
    LET reg[1] = 28
    LET reg[2] = 5
    LET r = eval_function(FN_MOD, reg)
    TEST_ASSERT("test_func.07201", r==0 AND reg.getLength()==1)
    TEST_ASSERT("test_func.07202", reg[1] IS NOT NULL AND reg[1] == 3.0)

    CALL reg.clear()
    LET reg[1] = 1000
    LET r = eval_function(FN_RAND, reg)
    TEST_ASSERT("test_func.07301", r==0 AND reg.getLength()==1)
    TEST_ASSERT("test_func.07302", reg[1] IS NOT NULL AND reg[1]>0.0 AND reg[1]<1000.0)

    CALL reg.clear()
    LET reg[1] = 180
    LET r = eval_function(FN_RAD, reg)
    TEST_ASSERT("test_func.07401", r==0 AND reg.getLength()==1)
    TEST_ASSERT("test_func.07402", reg[1] IS NOT NULL AND reg[1]==3.141592653589793)

    CALL reg.clear()
    LET reg[1] = 0.5
    LET r = eval_function(FN_DEG, reg)
    TEST_ASSERT("test_func.07501", r==0 AND reg.getLength()==1)
    TEST_ASSERT("test_func.07502", reg[1] IS NOT NULL AND reg[1]==28.64788975654116)

    CALL reg.clear()
    LET reg[1] = 1
    LET r = eval_function(FN_ATAN, reg)
    TEST_ASSERT("test_func.07601", r==0 AND reg.getLength()==1)
    TEST_ASSERT("test_func.07602", reg[1] IS NOT NULL AND reg[1] == 0.7853981633974483)

    CALL reg.clear()
    LET reg[1] = 1
    LET r = eval_function(FN_TAN, reg)
    TEST_ASSERT("test_func.07701", r==0 AND reg.getLength()==1)
    TEST_ASSERT("test_func.07702", reg[1] IS NOT NULL AND reg[1] == 1.5574077246549023)

    CALL reg.clear()
    LET reg[1] = 1
    LET reg[2] = 100
    LET reg[3] = 200
    LET r = eval_function(FN_IIF, reg)
    TEST_ASSERT("test_func.07801", r==0 AND reg.getLength()==1)
    TEST_ASSERT("test_func.07802", reg[1] IS NOT NULL AND reg[1] == 100)
    CALL reg.clear()
    LET reg[1] = 0
    LET reg[2] = 100
    LET reg[3] = 200
    LET r = eval_function(FN_IIF, reg)
    TEST_ASSERT("test_func.07811", r==0 AND reg.getLength()==1)
    TEST_ASSERT("test_func.07812", reg[1] IS NOT NULL AND reg[1] == 200)
    CALL reg.clear()
    LET reg[1] = 0
    LET reg[2] = 100
    LET r = eval_function(FN_IIF, reg)
    TEST_ASSERT("test_func.07811", r==EE_INVALID_OPERANDS )

    CALL reg.clear()
    LET reg[1] = 10
    LET r = eval_function(FN_ABS, reg)
    TEST_ASSERT("test_func.07901", r==0 AND reg.getLength()==1)
    TEST_ASSERT("test_func.07902", reg[1] IS NOT NULL AND reg[1] == 10)
    CALL reg.clear()
    LET reg[1] = -10
    LET r = eval_function(FN_ABS, reg)
    TEST_ASSERT("test_func.07911", r==0 AND reg.getLength()==1)
    TEST_ASSERT("test_func.07912", reg[1] IS NOT NULL AND reg[1] == 10)
    CALL reg.clear()
    LET r = eval_function(FN_ABS, reg)
    TEST_ASSERT("test_func.07921", r==EE_INVALID_OPERANDS )

    CALL reg.clear()
    LET reg[1] = 1
    LET reg[2] = 1
    LET r = eval_function(FN_SIN, reg)
    TEST_ASSERT("test_func.50001", r<=0 AND reg.getLength()==2)
    CALL reg.clear()
    LET r = eval_function(FN_SIN, reg)
    TEST_ASSERT("test_func.50002", r<=0 AND reg.getLength()==0)
    CALL reg.clear()
    LET reg[1] = 1
    LET r = eval_function(FN_MIN, reg)
    TEST_ASSERT("test_func.50003", r<=0 AND reg.getLength()==1)

END FUNCTION

&endif

PRIVATE FUNCTION eval_function(fn, reg)
    DEFINE fn STRING,
           reg DYNAMIC ARRAY OF t_number
    DEFINE x0,xl,xr SMALLINT
    LET xr = reg.getLength()
    LET xl = xr-1
    LET x0 = xr-2
    IF xr < function_arguments(fn) THEN
       RETURN EE_INVALID_OPERANDS
    END IF
    CASE fn
      WHEN FN_SIN
        LET reg[xr] = util.Math.sin(reg[xr])
      WHEN FN_ASIN
        LET reg[xr] = util.Math.asin(reg[xr])
      WHEN FN_COS
        LET reg[xr] = util.Math.cos(reg[xr])
      WHEN FN_ACOS
        LET reg[xr] = util.Math.acos(reg[xr])
      WHEN FN_TAN
        LET reg[xr] = util.Math.tan(reg[xr])
      WHEN FN_ATAN
        LET reg[xr] = util.Math.atan(reg[xr])
      WHEN FN_MIN
        LET reg[xl] = IIF(reg[xl] < reg[xr], reg[xl], reg[xr])
        CALL reg.deleteElement(xr)
      WHEN FN_MAX
        LET reg[xl] = IIF(reg[xl] > reg[xr], reg[xl], reg[xr])
        CALL reg.deleteElement(xr)
      WHEN FN_SQRT
        LET reg[xr] = fgl_decimal_sqrt(reg[xr])
      WHEN FN_EXP
        LET reg[xr] = fgl_decimal_exp(reg[xr])
      WHEN FN_LOGN
        LET reg[xr] = fgl_decimal_logn(reg[xr])
      WHEN FN_MOD
        LET reg[xl] = reg[xl] MOD reg[xr]
        CALL reg.deleteElement(xr)
      WHEN FN_RAND
        LET reg[xr] = util.Math.rand(reg[xr])
      WHEN FN_DEG
        LET reg[xr] = util.Math.toDegrees(reg[xr])
      WHEN FN_RAD
        LET reg[xr] = util.Math.toRadians(reg[xr])
      WHEN FN_IIF
        LET reg[x0] = IIF( reg[x0], reg[xl], reg[xr] )
        CALL reg.deleteElement(xr)
        CALL reg.deleteElement(xl)
      WHEN FN_ABS
        IF reg[xr] < 0 THEN
           LET reg[xr] = - reg[xr]
        END IF
      OTHERWISE
        ASSERT(FALSE)
    END CASE
    IF reg[ reg.getLength() ] IS NULL THEN
       RETURN EE_INVALID_ARGUMENT
    END IF
    RETURN 0
END FUNCTION

#---

&ifdef TEST

FUNCTION test_oper()
    DEFINE reg DYNAMIC ARRAY OF t_number,
           r SMALLINT

    CALL reg.clear()
    LET reg[1] = -1 -- not used
    LET reg[2] = -1 -- not used
    LET reg[3] = 5
    LET reg[4] = 3
    LET r = eval_operator(ET_OPER_EXP, reg)
    TEST_ASSERT("test_oper.01001", r==0 AND reg.getLength()==3)
    TEST_ASSERT("test_oper.01002", reg[3] IS NOT NULL AND reg[3] == 125)

    CALL reg.clear()
    LET reg[1] = 100
    LET reg[2] = 200
    LET r = eval_operator(ET_OPER_ADD, reg)
    TEST_ASSERT("test_oper.02001", r==0 AND reg.getLength()==1)
    TEST_ASSERT("test_oper.02002", reg[1] IS NOT NULL AND reg[1] == 300)

    CALL reg.clear()
    LET reg[1] = 100
    LET reg[2] = 200
    LET r = eval_operator(ET_OPER_SUB, reg)
    TEST_ASSERT("test_oper.03001", r==0 AND reg.getLength()==1)
    TEST_ASSERT("test_oper.03003", reg[1] IS NOT NULL AND reg[1] == -100)

    CALL reg.clear()
    LET reg[1] = 5
    LET reg[2] = -3
    LET r = eval_operator(ET_OPER_MUL, reg)
    TEST_ASSERT("test_oper.04001", r==0 AND reg.getLength()==1)
    TEST_ASSERT("test_oper.04004", reg[1] IS NOT NULL AND reg[1] == -15)

    CALL reg.clear()
    LET reg[1] = 15
    LET reg[2] = -3
    LET r = eval_operator(ET_OPER_DIV, reg)
    TEST_ASSERT("test_oper.05001", r==0 AND reg.getLength()==1)
    TEST_ASSERT("test_oper.05005", reg[1] IS NOT NULL AND reg[1] == -5)
    CALL reg.clear()
    LET reg[1] = 15
    LET reg[2] = 0
    LET r = eval_operator(ET_OPER_DIV, reg)
    TEST_ASSERT("test_oper.05011", r==EE_DIVISION_BY_ZERO )
    CALL reg.clear()
    CALL reg.clear()
    LET reg[1] = 15
    LET r = eval_operator(ET_OPER_DIV, reg)
    TEST_ASSERT("test_oper.05091", r==EE_INVALID_OPERANDS )

    CALL reg.clear()
    LET reg[1] = 15
    LET reg[2] = 15
    LET r = eval_operator(ET_OPER_EQL, reg)
    TEST_ASSERT("test_oper.07001", r==0 AND reg.getLength()==1)
    TEST_ASSERT("test_oper.07005", reg[1] IS NOT NULL AND reg[1] == 1)
    CALL reg.clear()
    LET reg[1] = 15
    LET reg[2] = 2
    LET r = eval_operator(ET_OPER_EQL, reg)
    TEST_ASSERT("test_oper.07011", r==0 AND reg.getLength()==1)
    TEST_ASSERT("test_oper.07015", reg[1] IS NOT NULL AND reg[1] == 0)

    CALL reg.clear()
    LET reg[1] = 15
    LET reg[2] = 15
    LET r = eval_operator(ET_OPER_NEQ, reg)
    TEST_ASSERT("test_oper.07101", r==0 AND reg.getLength()==1)
    TEST_ASSERT("test_oper.07105", reg[1] IS NOT NULL AND reg[1] == 0)
    CALL reg.clear()
    LET reg[1] = 15
    LET reg[2] = -2
    LET r = eval_operator(ET_OPER_NEQ, reg)
    TEST_ASSERT("test_oper.07111", r==0 AND reg.getLength()==1)
    TEST_ASSERT("test_oper.07115", reg[1] IS NOT NULL AND reg[1] == 1)

    CALL reg.clear()
    LET reg[1] = 15
    LET reg[2] = -2
    LET r = eval_operator(ET_OPER_GRE, reg)
    TEST_ASSERT("test_oper.07201", r==0 AND reg.getLength()==1)
    TEST_ASSERT("test_oper.07205", reg[1] IS NOT NULL AND reg[1] == 1)
    CALL reg.clear()
    LET reg[1] = 15
    LET reg[2] = 15
    LET r = eval_operator(ET_OPER_GRE, reg)
    TEST_ASSERT("test_oper.07211", r==0 AND reg.getLength()==1)
    TEST_ASSERT("test_oper.07215", reg[1] IS NOT NULL AND reg[1] == 0)

    CALL reg.clear()
    LET reg[1] = 15
    LET reg[2] = 15
    LET r = eval_operator(ET_OPER_GRE_EQL, reg)
    TEST_ASSERT("test_oper.07301", r==0 AND reg.getLength()==1)
    TEST_ASSERT("test_oper.07305", reg[1] IS NOT NULL AND reg[1] == 1)
    CALL reg.clear()
    LET reg[1] = 16
    LET reg[2] = 15
    LET r = eval_operator(ET_OPER_GRE_EQL, reg)
    TEST_ASSERT("test_oper.07311", r==0 AND reg.getLength()==1)
    TEST_ASSERT("test_oper.07315", reg[1] IS NOT NULL AND reg[1] == 1)
    CALL reg.clear()
    LET reg[1] = 14
    LET reg[2] = 15
    LET r = eval_operator(ET_OPER_GRE_EQL, reg)
    TEST_ASSERT("test_oper.07321", r==0 AND reg.getLength()==1)
    TEST_ASSERT("test_oper.07325", reg[1] IS NOT NULL AND reg[1] == 0)

    CALL reg.clear()
    LET reg[1] = -2
    LET reg[2] = 15
    LET r = eval_operator(ET_OPER_LOW, reg)
    TEST_ASSERT("test_oper.07401", r==0 AND reg.getLength()==1)
    TEST_ASSERT("test_oper.07405", reg[1] IS NOT NULL AND reg[1] == 1)
    CALL reg.clear()
    LET reg[1] = 15
    LET reg[2] = 15
    LET r = eval_operator(ET_OPER_LOW, reg)
    TEST_ASSERT("test_oper.07411", r==0 AND reg.getLength()==1)
    TEST_ASSERT("test_oper.07415", reg[1] IS NOT NULL AND reg[1] == 0)

    CALL reg.clear()
    LET reg[1] = 15
    LET reg[2] = 15
    LET r = eval_operator(ET_OPER_LOW_EQL, reg)
    TEST_ASSERT("test_oper.07501", r==0 AND reg.getLength()==1)
    TEST_ASSERT("test_oper.07505", reg[1] IS NOT NULL AND reg[1] == 1)
    CALL reg.clear()
    LET reg[1] = 14
    LET reg[2] = 15
    LET r = eval_operator(ET_OPER_LOW_EQL, reg)
    TEST_ASSERT("test_oper.07511", r==0 AND reg.getLength()==1)
    TEST_ASSERT("test_oper.07515", reg[1] IS NOT NULL AND reg[1] == 1)
    CALL reg.clear()
    LET reg[1] = 16
    LET reg[2] = 15
    LET r = eval_operator(ET_OPER_LOW_EQL, reg)
    TEST_ASSERT("test_oper.07521", r==0 AND reg.getLength()==1)
    TEST_ASSERT("test_oper.07525", reg[1] IS NOT NULL AND reg[1] == 0)

    CALL reg.clear()
    LET reg[1] = 1
    LET reg[2] = 1
    LET r = eval_operator(ET_OPER_AND, reg)
    TEST_ASSERT("test_oper.08001", r==0 AND reg.getLength()==1)
    TEST_ASSERT("test_oper.08005", reg[1] IS NOT NULL AND reg[1] == 1)
    CALL reg.clear()
    LET reg[1] = 1
    LET reg[2] = 0
    LET r = eval_operator(ET_OPER_AND, reg)
    TEST_ASSERT("test_oper.08011", r==0 AND reg.getLength()==1)
    TEST_ASSERT("test_oper.08015", reg[1] IS NOT NULL AND reg[1] == 0)
    CALL reg.clear()
    LET reg[1] = 0
    LET reg[2] = 0
    LET r = eval_operator(ET_OPER_AND, reg)
    TEST_ASSERT("test_oper.08021", r==0 AND reg.getLength()==1)
    TEST_ASSERT("test_oper.08025", reg[1] IS NOT NULL AND reg[1] == 0)

    CALL reg.clear()
    LET reg[1] = 1
    LET reg[2] = 1
    LET r = eval_operator(ET_OPER_OR, reg)
    TEST_ASSERT("test_oper.08101", r==0 AND reg.getLength()==1)
    TEST_ASSERT("test_oper.08105", reg[1] IS NOT NULL AND reg[1] == 1)
    CALL reg.clear()
    LET reg[1] = 1
    LET reg[2] = 0
    LET r = eval_operator(ET_OPER_OR, reg)
    TEST_ASSERT("test_oper.08111", r==0 AND reg.getLength()==1)
    TEST_ASSERT("test_oper.08115", reg[1] IS NOT NULL AND reg[1] == 1)
    CALL reg.clear()
    LET reg[1] = 0
    LET reg[2] = 0
    LET r = eval_operator(ET_OPER_OR, reg)
    TEST_ASSERT("test_oper.08121", r==0 AND reg.getLength()==1)
    TEST_ASSERT("test_oper.08125", reg[1] IS NOT NULL AND reg[1] == 0)

    CALL reg.clear()
    LET reg[1] = 1
    LET r = eval_operator(ET_OPER_NOT, reg)
    TEST_ASSERT("test_oper.08201", r==0 AND reg.getLength()==1)
    TEST_ASSERT("test_oper.08205", reg[1] IS NOT NULL AND reg[1] == 0)
    CALL reg.clear()
    LET reg[1] = 0
    LET r = eval_operator(ET_OPER_NOT, reg)
    TEST_ASSERT("test_oper.08211", r==0 AND reg.getLength()==1)
    TEST_ASSERT("test_oper.08215", reg[1] IS NOT NULL AND reg[1] == 1)

END FUNCTION

&endif

PRIVATE FUNCTION eval_operator(op,reg)
    DEFINE op t_elem_type,
           reg DYNAMIC ARRAY OF t_number
    DEFINE xl,xr SMALLINT,
           r, oc INTEGER
    LET xr = reg.getLength()
    IF op==ET_OPER_NOT THEN
       LET oc=1
    ELSE
       LET oc=2
    END IF
    IF xr < oc THEN
       RETURN EE_INVALID_OPERANDS
    END IF
    TRY
       LET xl = xr-1
       CASE op
         WHEN ET_OPER_EXP
           LET reg[xl] = fgl_decimal_power(reg[xl],reg[xr])
           IF reg[xl] IS NULL THEN
              LET r = EE_OVERFLOW_ERROR
           END IF
         WHEN ET_OPER_ADD
           LET reg[xl] = (reg[xl] + reg[xr])
         WHEN ET_OPER_SUB
           LET reg[xl] = (reg[xl] - reg[xr])
         WHEN ET_OPER_MUL
           LET reg[xl] = (reg[xl] * reg[xr])
         WHEN ET_OPER_DIV
           LET reg[xl] = (reg[xl] / reg[xr])
         WHEN ET_OPER_EQL
           LET reg[xl] = (reg[xl] == reg[xr])
         WHEN ET_OPER_NEQ
           LET reg[xl] = (reg[xl] != reg[xr])
         WHEN ET_OPER_GRE
           LET reg[xl] = (reg[xl] > reg[xr])
         WHEN ET_OPER_GRE_EQL
           LET reg[xl] = (reg[xl] >= reg[xr])
         WHEN ET_OPER_LOW
           LET reg[xl] = (reg[xl] < reg[xr])
         WHEN ET_OPER_LOW_EQL
           LET reg[xl] = (reg[xl] <= reg[xr])
         WHEN ET_OPER_AND
           LET reg[xl] = (reg[xl] AND reg[xr])
         WHEN ET_OPER_OR
           LET reg[xl] = (reg[xl] OR reg[xr])
         WHEN ET_OPER_NOT
           LET reg[xr] = NOT (reg[xr])
         OTHERWISE
           ASSERT(FALSE)
       END CASE
    CATCH
       CASE status
         WHEN -1202 LET r = EE_DIVISION_BY_ZERO
         --WHEN -1226 LET r = EE_OVERFLOW_ERROR -- Impossible with DEC(32)
         OTHERWISE  LET r = EE_OPERATOR_ERROR
       END CASE
    END TRY
    IF oc == 2 THEN
       CALL reg.deleteElement(xr)
    END IF
    RETURN r
END FUNCTION

#--

PRIVATE FUNCTION to_decimal(str)
    DEFINE str STRING -- t_number
    DEFINE dec t_number
    -- FIXME: Missing ISO dec/str conversion in core language...
    TRY
        CALL util.JSON.parse(str,dec)
    CATCH -- Conversion error
        RETURN NULL
    END TRY
    RETURN dec
END FUNCTION

#---

&ifdef TEST

PRIVATE FUNCTION test_output()
    DEFINE r BOOLEAN

    LET r = output_add_number(123.456)
    TEST_ASSERT("test_output.01001", r AND out[1].type = ET_VALUE AND out[1].value==123.456 )
    CALL output_clear()
    TEST_ASSERT("test_output.01002", out.getLength()==0 )

    LET r = output_add_number(-111.111)
    TEST_ASSERT("test_output.02001", r AND out[1].type = ET_VALUE AND out[1].value IS NOT NULL AND out[1].value==-111.111)
    LET r = output_add_function(FN_SIN)
    TEST_ASSERT("test_output.02003", r AND out[4].type = ET_FUNCTION AND out[3].name==FN_SIN )

    CALL output_clear()
    TEST_ASSERT("test_output.09001", out.getLength()==0 )

END FUNCTION

&endif

PRIVATE FUNCTION output_clear()
    CALL out.clear()
END FUNCTION

PRIVATE FUNCTION output_add(elem)
    DEFINE elem t_element
    DEFINE x INTEGER
    LET x = out.getLength() + 1
    LET out[x].* = elem.*
END FUNCTION

PRIVATE FUNCTION operator_operands(elem_type)
    DEFINE elem_type t_elem_type
    CASE elem_type
      WHEN ET_OPER_EXP     RETURN 2
      WHEN ET_OPER_ADD     RETURN 2
      WHEN ET_OPER_SUB     RETURN 2
      WHEN ET_OPER_DIV     RETURN 2
      WHEN ET_OPER_MUL     RETURN 2
      WHEN ET_OPER_UNA_MIN RETURN 1
      WHEN ET_OPER_UNA_PLS RETURN 1
      WHEN ET_OPER_EQL     RETURN 2
      WHEN ET_OPER_NEQ     RETURN 2
      WHEN ET_OPER_GRE     RETURN 2
      WHEN ET_OPER_GRE_EQL RETURN 2
      WHEN ET_OPER_LOW     RETURN 2
      WHEN ET_OPER_LOW_EQL RETURN 2
      WHEN ET_OPER_AND     RETURN 2
      WHEN ET_OPER_OR      RETURN 2
      WHEN ET_OPER_NOT     RETURN 1
      OTHERWISE            RETURN 0
    END CASE
END FUNCTION

PRIVATE FUNCTION check_operator(elem_type)
    DEFINE elem_type t_elem_type
    RETURN ( operator_operands(elem_type) > 0 )
END FUNCTION

PRIVATE FUNCTION function_arguments(token)
    DEFINE token STRING
    CASE token
      WHEN FN_ASIN  RETURN 1
      WHEN FN_SIN   RETURN 1
      WHEN FN_ACOS  RETURN 1
      WHEN FN_COS   RETURN 1
      WHEN FN_ATAN  RETURN 1
      WHEN FN_TAN   RETURN 1
      WHEN FN_MIN   RETURN 2
      WHEN FN_MAX   RETURN 2
      WHEN FN_SQRT  RETURN 1
      WHEN FN_EXP   RETURN 1
      WHEN FN_LOGN  RETURN 1
      WHEN FN_MOD   RETURN 2
      WHEN FN_RAND  RETURN 1
      WHEN FN_DEG   RETURN 1
      WHEN FN_RAD   RETURN 1
      WHEN FN_IIF   RETURN 3
      WHEN FN_ABS   RETURN 1
      OTHERWISE     RETURN -1
    END CASE
END FUNCTION

PRIVATE FUNCTION check_function(token)
    DEFINE token STRING
    RETURN ( function_arguments(token) >= 0 )
END FUNCTION

PRIVATE FUNCTION output_add_function(name)
    DEFINE name STRING
    DEFINE elem t_element
    IF NOT check_function(name) THEN
       RETURN FALSE
    END IF
    LET elem.type = ET_FUNCTION
    LET elem.name = name
    CALL output_add(elem.*)
    RETURN TRUE
END FUNCTION

PRIVATE FUNCTION output_add_number(value)
    DEFINE value t_number
    DEFINE elem t_element
    LET elem.value = value
    LET elem.type = ET_VALUE
    CALL output_add(elem.*)
    RETURN TRUE
END FUNCTION

#---

&ifdef TEST

PRIVATE FUNCTION test_stack()
    DEFINE elem t_element,
           r BOOLEAN

    LET r = stack_push_operator(ET_OPER_ADD)
    TEST_ASSERT("test_stack.01001", r AND stk[1].type = ET_OPER_ADD AND stk[1].name IS NULL AND stk[1].value IS NULL )
    LET r = stack_push_function(FN_SIN)
    TEST_ASSERT("test_stack.01002", r AND stk[2].type = ET_FUNCTION AND stk[2].name IS NOT NULL AND stk[2].name=="sin" )
    LET r = stack_push_function(FN_COS)
    TEST_ASSERT("test_stack.01003", r AND stk[3].type = ET_FUNCTION AND stk[3].name IS NOT NULL AND stk[3].name=="cos" )
    LET r = stack_push_operator(ET_OPER_MUL)
    TEST_ASSERT("test_stack.01004", r AND stk[4].type = ET_OPER_MUL AND stk[4].name IS NULL AND stk[4].value IS NULL )
    LET r = stack_push_control(ET_LEFT_BRACE)
    TEST_ASSERT("test_stack.01005", r AND stk[5].type = ET_LEFT_BRACE AND stk[5].name IS NULL AND stk[5].value IS NULL )
    LET r = stack_push_operator(ET_OPER_UNA_MIN)
    TEST_ASSERT("test_stack.01006", r AND stk[6].type = ET_OPER_UNA_MIN AND stk[6].name IS NULL AND stk[6].value IS NULL )
    CALL stack_pop() RETURNING elem.*
    TEST_ASSERT("test_stack.01007", stk.getLength()==5 AND elem.type = ET_OPER_UNA_MIN AND elem.name IS NULL AND elem.value IS NULL )
    CALL stack_pop() RETURNING elem.*
    TEST_ASSERT("test_stack.01008", stk.getLength()==4 AND elem.type = ET_LEFT_BRACE AND elem.name IS NULL AND elem.value IS NULL )
    CALL stack_pop() RETURNING elem.*
    TEST_ASSERT("test_stack.01009", stk.getLength()==3 AND elem.type = ET_OPER_MUL AND elem.name IS NULL AND elem.value IS NULL )
    LET elem.type = stack_next_type()
    TEST_ASSERT("test_stack.01010", stk.getLength()==3 AND elem.type = ET_FUNCTION )
    CALL stack_pop() RETURNING elem.*
    TEST_ASSERT("test_stack.01011", stk.getLength()==2 AND elem.type = ET_FUNCTION AND elem.name IS NOT NULL AND elem.name=="cos" )
    CALL stack_pop() RETURNING elem.*
    TEST_ASSERT("test_stack.01012", stk.getLength()==1 AND elem.type = ET_FUNCTION AND elem.name IS NOT NULL AND elem.name=="sin" )
    LET elem.type = stack_next_type()
    TEST_ASSERT("test_stack.01013", stk.getLength()==1 AND elem.type = ET_OPER_ADD )
    CALL stack_pop() RETURNING elem.*
    TEST_ASSERT("test_stack.01014", stk.getLength()==0 AND elem.type = ET_OPER_ADD AND elem.name IS NULL AND elem.value IS NULL )
    CALL stack_pop() RETURNING elem.*
    TEST_ASSERT("test_stack.01015", stk.getLength()==0 AND elem.type IS NULL )
    CALL stack_clear()
    TEST_ASSERT("test_stack.01099", stk.getLength()==0 )

END FUNCTION

&endif


PRIVATE FUNCTION stack_clear()
    CALL stk.clear()
END FUNCTION

PRIVATE FUNCTION _stack_push(elem)
    DEFINE elem t_element
    DEFINE x INTEGER
    LET x = stk.getLength() + 1
    LET stk[x].* = elem.*
END FUNCTION

PRIVATE FUNCTION stack_push_operator(oper)
    DEFINE oper t_elem_type
    DEFINE elem t_element
    LET elem.type = oper
    CALL _stack_push(elem.*)
    RETURN TRUE
END FUNCTION

PRIVATE FUNCTION stack_push_control(cont)
    DEFINE cont t_elem_type
    DEFINE elem t_element
    LET elem.type = cont
    CALL _stack_push(elem.*)
    RETURN TRUE
END FUNCTION

PRIVATE FUNCTION stack_push_function(name)
    DEFINE name STRING
    DEFINE elem t_element
    IF NOT check_function(name) THEN
       RETURN FALSE
    END IF
    LET elem.type = ET_FUNCTION
    LET elem.name = name
    CALL _stack_push(elem.*)
    RETURN TRUE
END FUNCTION

PRIVATE FUNCTION stack_next_type()
    IF stk.getLength() == 0 THEN
       RETURN NULL
    END IF
    RETURN stk[stk.getLength()].type
END FUNCTION

PRIVATE FUNCTION stack_pop()
    DEFINE elem t_element,
           x INTEGER
    LET x = stk.getLength()
    IF x == 0 THEN
       LET elem.type = NULL -- no more elements
       RETURN elem.*
    END IF
    LET elem.* = stk[x].*
    CALL stk.deleteElement(x)
    RETURN elem.*
END FUNCTION

PRIVATE FUNCTION stack_pop_trash()
    DEFINE x INTEGER
    LET x = stk.getLength()
    IF x > 0 THEN
       CALL stk.deleteElement(x)
    END IF
END FUNCTION

#---

&ifdef TEST

PRIVATE FUNCTION test_eval()
    DEFINE s SMALLINT, v t_number

    CALL setVariable("x1",15)
    CALL setVariable("x2",200)

    CALL evaluate("1") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.01001",s, s==0 AND NVL(v,0)==1.0)
    CALL evaluate("-4") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.01002",s, s==0 AND NVL(v,0)==-4.0)
    CALL evaluate("(-4)") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.01003",s, s==0 AND NVL(v,0)==-4.0)
    CALL evaluate("+4") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.01004",s, s==0 AND NVL(v,0)==4.0)
    CALL evaluate("(+4)") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.01005",s, s==0 AND NVL(v,0)==4.0)
    CALL evaluate("-4 - 2 + 2 - 3") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.01006",s, s==0 AND NVL(v,0)==-7.0)
    CALL evaluate("Pi") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.01007",s, s==0 AND NVL(v,0)==3.141592653589793238462643383279)

    CALL evaluate("x1") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.01106",s, s==0 AND NVL(v,0)==15.0)
    CALL evaluate("x2") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.01107",s, s==0 AND NVL(v,0)==200.0)

    CALL evaluate("(1-4)") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.02001",s, s==0 AND NVL(v,0)==-3.0)
    CALL evaluate("3 - -4") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.02002",s, s==0 AND NVL(v,0)==7.0)
    CALL evaluate("3 * 2 - 4") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.02003",s, s==0 AND NVL(v,0)==2.0)
    CALL evaluate("3 * (2 - 4)") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.02004",s, s==0 AND NVL(v,0)==-6.0)
    CALL evaluate("3/(2-4)") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.02005",s, s==0 AND NVL(v,0)==-1.5)
    CALL evaluate("3/(2+4)") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.02006",s, s==0 AND NVL(v,0)==0.5)
    CALL evaluate("1+100/100") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.02007",s, s==0 AND NVL(v,0)==2.0)
    CALL evaluate("(1+199)/100") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.02008",s, s==0 AND NVL(v,0)==2.0)
    CALL evaluate("5+5**3") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.02009",s, s==0 AND NVL(v,0)==130.0)
    CALL evaluate("2**3**2") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.02009",s, s==0 AND NVL(v,0)==512.0)
    CALL evaluate("(2**3)**2") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.02009",s, s==0 AND NVL(v,0)==64.0)
    CALL evaluate("-(3+2)-1") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.02010",s, s==0 AND NVL(v,0)==-6.0)
    CALL evaluate("3*5**2") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.02011",s, s==0 AND NVL(v,0)==75.0)
    CALL evaluate("(3+3)**2") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.02012",s, s==0 AND NVL(v,0)==36.0)

    CALL evaluate("x1+x2") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.03001",s, s==0 AND NVL(v,0)==215.0)
    CALL evaluate("((((x1+x2))))") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.03002",s, s==0 AND NVL(v,0)==215.0)
    CALL evaluate("(185+x1)/x2+1") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.03003",s, s==0 AND NVL(v,0)==2.0)

    CALL evaluate("sin(5)") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.04001",s, s==0 AND NVL(v,0)==-0.9589242746631385)
    CALL evaluate("sin(3.1+1.9)") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.04002",s, s==0 AND NVL(v,0)==-0.9589242746631385)
    CALL evaluate("cos(Pi/2)") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.04003",s, s==0 AND NVL(v,0)==6.123233995736766e-17)
    CALL evaluate("min ( x1, x2 ) ") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.04004",s, s==0 AND NVL(v,0)==15.0)
    CALL evaluate("min (-10*2, 4*0.3) ") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.04005",s, s==0 AND NVL(v,0)==-20.0)
    CALL evaluate("max (-10*2, 4*0.3) ") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.04006",s, s==0 AND NVL(v,0)==1.2)
    CALL evaluate("sqrt(99*99)") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.04007",s, s==0 AND NVL(v,0)==99)
    CALL evaluate("exp(34)") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.04008",s, s==0 AND NVL(v,0)==583461742527454.8814029027342221)
    CALL evaluate("logn(exp(34))") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.04009",s, s==0 AND NVL(v,0)==33.99999999999999999999999999957)
    CALL evaluate("exp(logn(10))") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.04010",s, s==0 AND NVL(v,0)==9.999999999999999999999999999791)
    CALL evaluate("mod(28,5)") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.04011",s, s==0 AND NVL(v,0)==3.0)
    CALL evaluate("asin(0.2)") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.04012",s, s==0 AND NVL(v,0)==0.2013579207903308)
    CALL evaluate("acos(0.2)") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.04013",s, s==0 AND NVL(v,0)==1.369438406004566)
    CALL evaluate("atan(0.2)") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.04014",s, s==0 AND NVL(v,0)==0.19739555984988078)
    CALL evaluate("deg(2)") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.04015",s, s==0 AND NVL(v,0)==114.59155902616465)
    CALL evaluate("rad(45)") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.04016",s, s==0 AND NVL(v,0)==0.7853981633974483)
    CALL evaluate("deg(rad(2))") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.04017",s, s==0 AND NVL(v,0)==2.0)
    CALL evaluate("iif(2>3,11,22)") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.04018",s, s==0 AND NVL(v,0)==22.0)
    CALL evaluate("iif(2==2,11,22)") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.04019",s, s==0 AND NVL(v,0)==11.0)
    CALL evaluate("abs(15)") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.04020",s, s==0 AND NVL(v,0)==15.0)
    CALL evaluate("abs(-15)") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.04021",s, s==0 AND NVL(v,0)==15.0)

    CALL evaluate("sin(max(x1,3)/15*0.5)") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.04999",s, s==0 AND NVL(v,0)==0.479425538604203)

    CALL evaluate("1==1") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.10001",s, s==0 AND NVL(v,0)==1.0)
    CALL evaluate("6*5 == 30") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.10002",s, s==0 AND NVL(v,0)==1.0)
    CALL evaluate("6*5 != 31") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.10003",s, s==0 AND NVL(v,0)==1.0)
    CALL evaluate("6*5 <= 30") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.10004",s, s==0 AND NVL(v,0)==1.0)
    CALL evaluate("6*5 < 31") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.10005",s, s==0 AND NVL(v,0)==1.0)
    CALL evaluate("6*5 >= 30") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.10006",s, s==0 AND NVL(v,0)==1.0)
    CALL evaluate("6*5 > 29") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.10007",s, s==0 AND NVL(v,0)==1.0)

    CALL evaluate("(5>2*2)+(4==2*2)") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.10101",s, s==0 AND NVL(v,0)==2.0)
    CALL evaluate(" 5>2*2 + 4==2*2") RETURNING s, v -- (5>(2*2+4)) == (2*2)
    TEST_ASSERT_EVAL("test_evaluate.10101",s, s==0 AND NVL(v,0)==0.0)

    CALL evaluate("1 and 0") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.11001",s, s==0 AND NVL(v,0)==0.0)
    CALL evaluate("1 and 1") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.11002",s, s==0 AND NVL(v,0)==1.0)
    CALL evaluate("0 and 1") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.11003",s, s==0 AND NVL(v,0)==0.0)
    CALL evaluate("0 and 0") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.11004",s, s==0 AND NVL(v,0)==0.0)

    CALL evaluate("1 or 0") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.11101",s, s==0 AND NVL(v,0)==1.0)
    CALL evaluate("1 or 1") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.11102",s, s==0 AND NVL(v,0)==1.0)
    CALL evaluate("0 or 1") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.11103",s, s==0 AND NVL(v,0)==1.0)
    CALL evaluate("0 or 0") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.11104",s, s==0 AND NVL(v,0)==0.0)

    CALL evaluate("1 or 0 and 1 or 0") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.11101",s, s==0 AND NVL(v,0)==1.0)
    CALL evaluate("1 and 0 or 1 and 0") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.11102",s, s==0 AND NVL(v,0)==0.0)

    CALL evaluate("not 1") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.12001",s, s==0 AND NVL(v,0)==0.0)
    CALL evaluate("not 0") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.12002",s, s==0 AND NVL(v,0)==1.0)
    CALL evaluate("not 0 or 1") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.12003",s, s==0 AND NVL(v,0)==1.0)
    CALL evaluate("not 1 or 0") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.12004",s, s==0 AND NVL(v,0)==0.0)
    CALL evaluate("not 1 and 1") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.12005",s, s==0 AND NVL(v,0)==0.0)
    CALL evaluate("not 0 and 1") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.12006",s, s==0 AND NVL(v,0)==1.0)
    CALL evaluate("not 0 + 1") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.12007",s, s==0 AND NVL(v,0)==0.0)
    CALL evaluate("not (0 + 1)") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.12008",s, s==0 AND NVL(v,0)==0.0)
    CALL evaluate("(not 0) + 1") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.12009",s, s==0 AND NVL(v,0)==2.0)
    CALL evaluate("(not 1 or 2) + 5 / 100") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.12010",s, s==0 AND NVL(v,0)==1.05)

    -- Errors

    CALL evaluate("-") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.90001",s, s==EE_SYNTAX_ERROR AND v IS NULL)
    CALL evaluate("+") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.90002",s, s==EE_SYNTAX_ERROR AND v IS NULL)
    CALL evaluate("*") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.90003",s, s==EE_SYNTAX_ERROR AND v IS NULL)
    CALL evaluate("/") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.90004",s, s==EE_SYNTAX_ERROR AND v IS NULL)
    CALL evaluate("**") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.90005",s, s==EE_SYNTAX_ERROR AND v IS NULL)
    CALL evaluate("**1") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.90006",s, s==EE_SYNTAX_ERROR AND v IS NULL)
    CALL evaluate("*1") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.90007",s, s==EE_SYNTAX_ERROR AND v IS NULL)
    CALL evaluate("/1") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.90008",s, s==EE_SYNTAX_ERROR AND v IS NULL)
    CALL evaluate("^%#$") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.90009",s, s==EE_SYNTAX_ERROR AND v IS NULL)

    CALL evaluate("(1+2") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.90101",s, s==EE_PARENTHESES_MISMATCH AND v IS NULL)
    CALL evaluate("(1+2))") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.90102",s, s==EE_PARENTHESES_MISMATCH AND v IS NULL)
    CALL evaluate("min(1,") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.90103",s, s==EE_PARENTHESES_MISMATCH AND v IS NULL)
    CALL evaluate("min(1,2") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.90105",s, s==EE_PARENTHESES_MISMATCH AND v IS NULL)
    CALL evaluate("min(1,2))") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.90106",s, s==EE_PARENTHESES_MISMATCH AND v IS NULL)
    CALL evaluate("-(3*(4+2)") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.90107",s, s==EE_PARENTHESES_MISMATCH AND v IS NULL)

    CALL evaluate("min(,)") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.90201",s, s==EE_SYNTAX_ERROR AND v IS NULL)
    CALL evaluate("min(,,)") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.90202",s, s==EE_SYNTAX_ERROR AND v IS NULL)
    CALL evaluate("min(1,)") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.90203",s, s==EE_SYNTAX_ERROR AND v IS NULL)
    CALL evaluate("min(1,,)") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.90204",s, s==EE_SYNTAX_ERROR AND v IS NULL)
    CALL evaluate("min(1,2,)") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.90205",s, s==EE_SYNTAX_ERROR AND v IS NULL)
    CALL evaluate("min(1,max(3,2),)") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.90206",s, s==EE_SYNTAX_ERROR AND v IS NULL)
    CALL evaluate("*5") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.90207",s, s==EE_SYNTAX_ERROR AND v IS NULL)
    CALL evaluate("5(*5)") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.90208",s, s==EE_SYNTAX_ERROR AND v IS NULL)
    CALL evaluate("5+*5") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.90209",s, s==EE_SYNTAX_ERROR AND v IS NULL)
    CALL evaluate(")78*1 (1+3))") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.90210",s, s==EE_SYNTAX_ERROR AND v IS NULL)
    CALL evaluate("sin(*)") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.90211",s, s==EE_SYNTAX_ERROR AND v IS NULL)

    CALL evaluate("1 - ") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.90301",s, s==EE_INVALID_OPERANDS AND v IS NULL)
    CALL evaluate("1 + ") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.90302",s, s==EE_INVALID_OPERANDS AND v IS NULL)
    CALL evaluate("1 / ") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.90303",s, s==EE_INVALID_OPERANDS AND v IS NULL)
    CALL evaluate("1 * ") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.90304",s, s==EE_INVALID_OPERANDS AND v IS NULL)
    CALL evaluate("1 ** ") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.90305",s, s==EE_INVALID_OPERANDS AND v IS NULL)
    CALL evaluate("1 == ") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.90306",s, s==EE_INVALID_OPERANDS AND v IS NULL)
    CALL evaluate("1 != ") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.90307",s, s==EE_INVALID_OPERANDS AND v IS NULL)
    CALL evaluate("1 > ") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.90308",s, s==EE_INVALID_OPERANDS AND v IS NULL)
    CALL evaluate("1 >= ") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.90309",s, s==EE_INVALID_OPERANDS AND v IS NULL)
    CALL evaluate("1 < ") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.90310",s, s==EE_INVALID_OPERANDS AND v IS NULL)
    CALL evaluate("1 <= ") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.90311",s, s==EE_INVALID_OPERANDS AND v IS NULL)
    CALL evaluate("iif(1,2) ") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.90313",s, s==EE_INVALID_OPERANDS AND v IS NULL)

    CALL evaluate("cos(1,2)") RETURNING s, v
    TEST_ASSERT_EVAL("test_evaluate.90401",s, s==EE_COMP_STACK_ERROR AND v IS NULL)

END FUNCTION

&endif

PRIVATE FUNCTION unary_candidate(token, last_elem_type)
    DEFINE token, last_elem_type STRING
    IF token=="-" OR token=="+" THEN
       RETURN (
          last_elem_type == 0
       OR last_elem_type == ET_OPER_MUL
       OR last_elem_type == ET_OPER_DIV
       OR last_elem_type == ET_OPER_ADD
       OR last_elem_type == ET_OPER_SUB
       OR last_elem_type == ET_OPER_EQL
       OR last_elem_type == ET_OPER_NEQ
       OR last_elem_type == ET_OPER_LOW
       OR last_elem_type == ET_OPER_LOW_EQL
       OR last_elem_type == ET_OPER_GRE
       OR last_elem_type == ET_OPER_GRE_EQL
       OR last_elem_type == ET_OPER_AND
       OR last_elem_type == ET_OPER_OR
       OR last_elem_type == ET_OPER_NOT
       OR last_elem_type == ET_LEFT_BRACE
       )
    END IF
    RETURN FALSE
END FUNCTION

PRIVATE FUNCTION predefine_constants()
    CALL setVariable("Pi", 3.1415926535897932384626433832795) -- util.Math.pi())
    CALL setVariable("Euler",2.7182818284)
    CALL setVariable("Golden",1.6180339887498948482)
END FUNCTION

PUBLIC FUNCTION initialize()
    LET init_count = init_count+1
    IF init_count==1 THEN
       CALL liblexer.initialize()
       CALL predefine_constants()
    END IF
END FUNCTION

PUBLIC FUNCTION finalize()
    LET init_count = init_count-1
    IF init_count==0 THEN
       CALL vars.clear()
       CALL liblexer.finalize()
    END IF
END FUNCTION

PUBLIC FUNCTION evaluate(expr)
    DEFINE expr STRING
    DEFINE r SMALLINT,
           value t_number
    LET r = prepare(expr)
    IF r<0 THEN
       RETURN r, NULL
    END IF
    CALL compute( ) RETURNING r, value
&ifdef DEBUG
display sfmt("res: (status:%1) %2", r, value)
&endif
    RETURN r, value
END FUNCTION

PRIVATE FUNCTION token_to_elem_type(tokid, token, next_tokid, next_token)
    DEFINE tokid SMALLINT, token STRING,
           next_tokid SMALLINT, next_token STRING
    IF tokid==SL_TOKID_OTHER THEN
       CASE
         WHEN token=="*" AND next_tokid==SL_TOKID_OTHER AND next_token=="*" RETURN ET_OPER_EXP, 2
         WHEN token=="=" AND next_tokid==SL_TOKID_OTHER AND next_token=="=" RETURN ET_OPER_EQL, 2
         WHEN token=="!" AND next_tokid==SL_TOKID_OTHER AND next_token=="=" RETURN ET_OPER_NEQ, 2
         WHEN token=="<" AND next_tokid==SL_TOKID_OTHER AND next_token=="=" RETURN ET_OPER_LOW_EQL, 2
         WHEN token==">" AND next_tokid==SL_TOKID_OTHER AND next_token=="=" RETURN ET_OPER_GRE_EQL, 2
         WHEN token=="+" RETURN ET_OPER_ADD, 1
         WHEN token=="-" RETURN ET_OPER_SUB, 1
         WHEN token=="/" RETURN ET_OPER_DIV, 1
         WHEN token=="*" RETURN ET_OPER_MUL, 1
         WHEN token==">" RETURN ET_OPER_GRE, 1
         WHEN token=="<" RETURN ET_OPER_LOW, 1
         WHEN token=="(" RETURN ET_LEFT_BRACE, 1
         WHEN token==")" RETURN ET_RIGHT_BRACE, 1
         WHEN token=="," RETURN ET_COMMA, 1
       END CASE
    END IF
    IF tokid==SL_TOKID_IDENT THEN
       CASE
         WHEN token=="and" RETURN ET_OPER_AND, 1
         WHEN token=="or"  RETURN ET_OPER_OR, 1
         WHEN token=="not" RETURN ET_OPER_NOT, 1
       END CASE
    END IF
    RETURN NULL, 0
END FUNCTION

PRIVATE FUNCTION prepare(expr)
    DEFINE expr STRING
    DEFINE buf base.StringBuffer,
           pos INTEGER, tokid SMALLINT, token STRING,
           last_pos INTEGER, last_tokid SMALLINT, last_token STRING,
           next_pos INTEGER, next_tokid SMALLINT, next_token STRING,
           elem_type t_elem_type,
           last_elem_type t_elem_type,
           value t_number,
           nbtokens, s SMALLINT
&ifdef DEBUG
display "\nin : ", expr
&endif
    CALL output_clear()
    CALL stack_clear()
    LET buf = base.StringBuffer.create()
    CALL buf.append(expr)
    LET pos = 1
    WHILE tokid != SL_TOKID_END
       IF tokid > 0 THEN
          LET last_pos = pos
          LET last_tokid = tokid
          LET last_token = token
          LET last_elem_type = elem_type
       END IF
       CALL liblexer.getNextToken(buf,pos,TRUE) RETURNING tokid,pos,token
       CALL liblexer.getNextToken(buf,pos,TRUE) RETURNING next_tokid,next_pos,next_token
&ifdef DEBUG
display "pos=", pos USING "##&", " tid=", tokid USING "---&", " token:[", token, "]", column 60, "last:[", last_token, "]", column 90, "next:[", next_token,"]"
&endif
       IF tokid<0 THEN
          RETURN tokid
       END IF

       IF tokid==SL_TOKID_END THEN
          EXIT WHILE
       END IF

       IF tokid==SL_TOKID_OTHER AND unary_candidate(token,last_elem_type) THEN
          IF token=="-" THEN
             LET s = stack_push_operator(ET_OPER_UNA_MIN)
          ELSE
             LET s = stack_push_operator(ET_OPER_UNA_PLS)
          END IF
          CONTINUE WHILE
       END IF

       CALL token_to_elem_type(tokid, token, next_tokid, next_token) RETURNING elem_type, nbtokens
       IF nbtokens==2 THEN
          LET pos = next_pos
          LET tokid = next_tokid
          LET token = next_token
       END IF

       IF elem_type IS NULL THEN
          CASE
            WHEN tokid==SL_TOKID_STRING
              RETURN EE_SYNTAX_ERROR
            WHEN tokid==SL_TOKID_NUMBER
              LET value = to_decimal(token)
              IF value IS NULL THEN
                 RETURN EE_INVALID_NUMBER
              ELSE
                 LET s = output_add_number(value)
              END IF
            WHEN tokid==SL_TOKID_IDENT
              IF next_tokid==SL_TOKID_OTHER AND next_token=="(" THEN
                 IF NOT stack_push_function(token) THEN
                    RETURN EE_INVALID_FUNCTION
                 END IF
              ELSE -- Variable
                 LET value = getVariable(token)
                 IF value IS NULL THEN
                    RETURN EE_UNDEFINED_VARIABLE
                 ELSE
                    LET s = output_add_number(value)
                 END IF
              END IF
            OTHERWISE
              RETURN EE_SYNTAX_ERROR
          END CASE
       ELSE
          CASE
            WHEN elem_type==ET_COMMA
              LET s = pop_stack_to_output_until(ET_LEFT_BRACE)
              IF s<0 THEN RETURN s END IF
            WHEN check_operator(elem_type)
              IF operator_operands(elem_type) > 1
                 AND (last_elem_type == 0
                      OR check_operator(last_elem_type)
                      OR last_elem_type==ET_LEFT_BRACE)
              THEN
                 RETURN EE_SYNTAX_ERROR
              END IF
              LET s = pop_operators_to_output(elem_type)
              IF s<0 THEN RETURN s END IF
              LET s = stack_push_operator(elem_type)
            WHEN elem_type==ET_LEFT_BRACE
              LET s = stack_push_control(elem_type)
            WHEN elem_type==ET_RIGHT_BRACE
              IF last_elem_type == 0
              OR check_operator(last_elem_type)
              OR last_elem_type==ET_LEFT_BRACE
              OR last_elem_type==ET_COMMA THEN
                 RETURN EE_SYNTAX_ERROR
              END IF
              LET s = pop_stack_to_output_until(ET_LEFT_BRACE)
              IF s<0 THEN RETURN s END IF
              CALL stack_pop_trash()
              IF stack_next_type()==ET_FUNCTION THEN
                 CALL pop_stack_to_output()
              END IF
            OTHERWISE
              RETURN EE_SYNTAX_ERROR
          END CASE
       END IF

&ifdef DEBUG
display "      output: ", util.JSON.stringify(out)
display "      stack : ", util.JSON.stringify(stk)
display "      --------"
&endif

    END WHILE

    LET s = pop_stack_to_output_to_end()
    IF s<0 THEN RETURN s END IF

&ifdef DEBUG
display " last output: ", util.JSON.stringify(out)
&endif

    RETURN 0

END FUNCTION

PRIVATE FUNCTION compute( )
    DEFINE x, m INTEGER,
           r SMALLINT,
           reg DYNAMIC ARRAY OF t_number,
           rx INTEGER
    LET rx = 0
    LET m = out.getLength()
    FOR x=1 TO m
        CASE
            WHEN out[x].type == ET_VALUE
              LET reg[rx:=rx+1] = out[x].value
            WHEN out[x].type == ET_OPER_UNA_MIN
              IF rx<=0 THEN RETURN EE_SYNTAX_ERROR, NULL END IF
              LET reg[rx] = - reg[rx]
            WHEN out[x].type == ET_OPER_UNA_PLS
              IF rx<=0 THEN RETURN EE_SYNTAX_ERROR, NULL END IF
              --LET reg[rx] = reg[rx]
            WHEN out[x].type == ET_FUNCTION
              LET r = eval_function(out[x].name, reg)
              IF r<0 THEN RETURN r, NULL END IF
              LET rx = reg.getLength()
            OTHERWISE -- Operator
              LET r = eval_operator(out[x].type, reg)
              IF r<0 THEN RETURN r, NULL END IF
              LET rx = reg.getLength()
        END CASE
    END FOR
    IF reg.getLength()!=1 THEN
       RETURN EE_COMP_STACK_ERROR, NULL
    END IF
    RETURN 0, reg[1]
END FUNCTION

PRIVATE FUNCTION pop_stack_to_output()
    DEFINE elem t_element
    ASSERT( stk.getLength()>0 )
    CALL stack_pop() RETURNING elem.*
    CALL output_add(elem.*)
END FUNCTION

PRIVATE FUNCTION pop_stack_to_output_until(stop_type)
    DEFINE stop_type t_elem_type
    DEFINE elem t_element,
           t t_elem_type
    WHILE TRUE
        LET t = stack_next_type()
        IF t IS NULL THEN
           RETURN EE_PARENTHESES_MISMATCH
        END IF
        IF t==stop_type THEN
           EXIT WHILE
        END IF
        CALL stack_pop() RETURNING elem.*
        CALL output_add(elem.*)
    END WHILE
    RETURN 0
END FUNCTION

PRIVATE FUNCTION pop_stack_to_output_to_end()
    DEFINE elem t_element,
           t t_elem_type
    LET t = stack_next_type()
    WHILE t IS NOT NULL
        IF t==ET_LEFT_BRACE OR t==ET_RIGHT_BRACE THEN
           RETURN EE_PARENTHESES_MISMATCH
        END IF
        CALL stack_pop() RETURNING elem.*
        CALL output_add(elem.*)
        LET t = stack_next_type()
    END WHILE
    RETURN 0
END FUNCTION

PRIVATE FUNCTION left_associative(oper)
    DEFINE oper t_elem_type
    CASE oper
      WHEN ET_OPER_EXP       RETURN FALSE
      WHEN ET_OPER_NOT       RETURN FALSE
      OTHERWISE              RETURN TRUE
    END CASE
END FUNCTION

PRIVATE FUNCTION precedence_index(oper)
    DEFINE oper t_elem_type
    CASE oper
      WHEN ET_OPER_UNA_MIN   RETURN 8
      WHEN ET_OPER_UNA_PLS   RETURN 8
      WHEN ET_OPER_EXP       RETURN 7
      WHEN ET_OPER_MUL       RETURN 6
      WHEN ET_OPER_DIV       RETURN 6
      WHEN ET_OPER_ADD       RETURN 5
      WHEN ET_OPER_SUB       RETURN 5
      WHEN ET_OPER_EQL       RETURN 4
      WHEN ET_OPER_NEQ       RETURN 4
      WHEN ET_OPER_GRE       RETURN 4
      WHEN ET_OPER_GRE_EQL   RETURN 4
      WHEN ET_OPER_LOW       RETURN 4
      WHEN ET_OPER_LOW_EQL   RETURN 4
      WHEN ET_OPER_NOT       RETURN 3
      WHEN ET_OPER_AND       RETURN 2
      WHEN ET_OPER_OR        RETURN 1
      OTHERWISE              ASSERT(FALSE)
    END CASE
    RETURN NULL
END FUNCTION

PRIVATE FUNCTION pop_operators_to_output(first)
    DEFINE first t_elem_type
    DEFINE t t_elem_type,
           elem t_element,
           fla BOOLEAN,
           fpi SMALLINT
    LET fla = left_associative(first)
    LET fpi = precedence_index(first)
    WHILE TRUE
        LET t = stack_next_type()
        IF NOT check_operator(t) THEN
           EXIT WHILE
        END IF
        IF ( fla     AND precedence_index(t) >= fpi )
        OR ( NOT fla AND precedence_index(t) >  fpi )
        THEN
           CALL stack_pop() RETURNING elem.*
           CALL output_add(elem.*)
        ELSE
           EXIT WHILE
        END IF
    END WHILE
    RETURN 0
END FUNCTION
