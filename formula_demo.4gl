IMPORT FGL libformula

DEFINE rec RECORD
           input STRING,
           status SMALLINT,
           message STRING,
           result DECIMAL(32),
           var_name STRING,
           var_value DECIMAL(32)
       END RECORD

DEFINE varlist libformula.t_varlist

MAIN

    OPEN FORM f1 FROM "formula_demo"
    DISPLAY FORM f1

    CALL libformula.initialize()

    DIALOG ATTRIBUTES(UNBUFFERED)

    INPUT BY NAME rec.*
    END INPUT

    DISPLAY ARRAY varlist TO sr.*
        BEFORE ROW
           CALL sync_var_fields(DIALOG.getCurrentRow("sr"))
    END DISPLAY

    BEFORE DIALOG
        CALL sync_var_list()
        CALL sync_var_fields(DIALOG.getCurrentRow("sr"))

    ON ACTION n_0       CALL append("0",FALSE)
    ON ACTION n_1       CALL append("1",FALSE)
    ON ACTION n_2       CALL append("2",FALSE)
    ON ACTION n_3       CALL append("3",FALSE)
    ON ACTION n_4       CALL append("4",FALSE)
    ON ACTION n_5       CALL append("5",FALSE)
    ON ACTION n_6       CALL append("6",FALSE)
    ON ACTION n_7       CALL append("7",FALSE)
    ON ACTION n_8       CALL append("8",FALSE)
    ON ACTION n_9       CALL append("9",FALSE)
    ON ACTION n_dot     CALL append(".",FALSE)
    ON ACTION oper_add  CALL append("+",TRUE)
    ON ACTION oper_sub  CALL append("-",TRUE)
    ON ACTION oper_mul  CALL append("*",TRUE)
    ON ACTION oper_div  CALL append("/",TRUE)
    ON ACTION oper_exp  CALL append("**",TRUE)
    ON ACTION oper_cbr  CALL append(")",TRUE)
    ON ACTION oper_and  CALL append("and",TRUE)
    ON ACTION oper_or   CALL append("or",TRUE)
    ON ACTION oper_not  CALL append("not",TRUE)
    ON ACTION clear     LET rec.input = NULL
    ON ACTION f_sin     CALL append("sin(",TRUE)
    ON ACTION f_asin    CALL append("asin(",TRUE)
    ON ACTION f_cos     CALL append("cos(",TRUE)
    ON ACTION f_acos    CALL append("acos(",TRUE)
    ON ACTION f_tan     CALL append("tan(",TRUE)
    ON ACTION f_atan    CALL append("atan(",TRUE)
    ON ACTION f_min     CALL append("min(",TRUE)
    ON ACTION f_max     CALL append("max(",TRUE)
    ON ACTION f_sqrt    CALL append("sqrt(",TRUE)
    ON ACTION f_exp     CALL append("exp(",TRUE)
    ON ACTION f_logn    CALL append("logn(",TRUE)
    ON ACTION f_mod     CALL append("mod(",TRUE)
    ON ACTION f_rand    CALL append("rand(",TRUE)
    ON ACTION f_rad     CALL append("rad(",TRUE)
    ON ACTION f_deg     CALL append("deg(",TRUE)
    ON ACTION f_iif     CALL append("iif(",TRUE)
    ON ACTION f_abs     CALL append("abs(",TRUE)

    ON ACTION copy_result ATTRIBUTES(ACCELERATOR="Control-U")
       IF rec.result IS NOT NULL THEN
          LET rec.var_value = rec.result
          LET rec.var_name = SFMT("result_%1",varlist.getLength()+1)
          CALL libformula.setVariable( rec.var_name,  rec.var_value )
          CALL sync_var_list()
       END IF

    ON ACTION set_variable ATTRIBUTES(ACCELERATOR="Control-S")
       IF rec.var_name IS NOT NULL AND rec.var_value IS NOT NULL THEN
          CALL libformula.setVariable( rec.var_name,  rec.var_value )
          CALL sync_var_list()
       END IF

    ON ACTION clr_variable ATTRIBUTES(ACCELERATOR="Control-D")
       IF rec.var_name IS NOT NULL THEN
          CALL libformula.clearVariable( rec.var_name )
          CALL sync_var_list()
       END IF

    ON ACTION eval ATTRIBUTES(ACCELERATOR="RETURN")
       CALL libformula.evaluate(rec.input) RETURNING rec.status, rec.result
       LET rec.message = IIF(rec.status==0,NULL,getErrorMessage(rec.status))

    ON ACTION close
       EXIT DIALOG

    END DIALOG

    CALL libformula.finalize()

END MAIN

FUNCTION append(p,s)
    DEFINE p STRING, s BOOLEAN
    DEFINE b base.StringBuffer,
           sels,sele,tmp, ilen SMALLINT
    IF s THEN
       LET p = " ", p, " "
    END IF
    LET b = base.StringBuffer.create()
    LET ilen = rec.input.getLength()
    LET sels = fgl_dialog_getcursor()
    LET sele = fgl_dialog_getselectionend()
    IF sels > sele THEN
       LET tmp = sele
       LET sele = sels
       LET sels = tmp
    END IF
    CALL b.append(rec.input)
    IF sels==sele THEN
       IF sels <= ilen THEN
          CALL b.insertAt(sels, p)
          LET sels = sels + p.getLength()
          LET sele = sels
       ELSE
          CALL b.append(p)
          LET sels = b.getLength() + 1
          LET sele = sels
       END IF
    ELSE
       CALL b.replaceAt(sels, (sele-sels), p)
       LET sele = sels + p.getLength()
    END IF
    LET rec.input = b.toString()
    CALL fgl_dialog_setselection( sels, sele )
END FUNCTION

FUNCTION sync_var_fields(x)
    DEFINE x INTEGER
    IF x>0 THEN
       LET rec.var_name = varlist[x].name
       LET rec.var_value = libformula.getVariable(rec.var_name)
    ELSE
       LET rec.var_name = NULL
       LET rec.var_value = NULL
    END IF
END FUNCTION

FUNCTION sync_var_list()
    CALL libformula.getVariableList(varlist)
END FUNCTION
