IMPORT FGL libformula

DEFINE rec RECORD
           src STRING,
           sta SMALLINT,
           msg STRING,
           res DECIMAL(32),
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

    ON ACTION n_0       CALL append_element("0",FALSE)
    ON ACTION n_1       CALL append_element("1",FALSE)
    ON ACTION n_2       CALL append_element("2",FALSE)
    ON ACTION n_3       CALL append_element("3",FALSE)
    ON ACTION n_4       CALL append_element("4",FALSE)
    ON ACTION n_5       CALL append_element("5",FALSE)
    ON ACTION n_6       CALL append_element("6",FALSE)
    ON ACTION n_7       CALL append_element("7",FALSE)
    ON ACTION n_8       CALL append_element("8",FALSE)
    ON ACTION n_9       CALL append_element("9",FALSE)
    ON ACTION n_dot     CALL append_element(".",FALSE)
    ON ACTION oper_add  CALL append_element("+",TRUE)
    ON ACTION oper_sub  CALL append_element("-",TRUE)
    ON ACTION oper_mul  CALL append_element("*",TRUE)
    ON ACTION oper_div  CALL append_element("/",TRUE)
    ON ACTION oper_exp  CALL append_element("**",TRUE)
    ON ACTION oper_cbr  CALL append_element(")",TRUE)
    ON ACTION oper_and  CALL append_element("and",TRUE)
    ON ACTION oper_or   CALL append_element("or",TRUE)
    ON ACTION oper_not  CALL append_element("not",TRUE)
    ON ACTION clear     LET rec.src = NULL
    ON ACTION f_sin     CALL append_element("sin(",TRUE)
    ON ACTION f_asin    CALL append_element("asin(",TRUE)
    ON ACTION f_cos     CALL append_element("cos(",TRUE)
    ON ACTION f_acos    CALL append_element("acos(",TRUE)
    ON ACTION f_tan     CALL append_element("tan(",TRUE)
    ON ACTION f_atan    CALL append_element("atan(",TRUE)
    ON ACTION f_min     CALL append_element("min(",TRUE)
    ON ACTION f_max     CALL append_element("max(",TRUE)
    ON ACTION f_sqrt    CALL append_element("sqrt(",TRUE)
    ON ACTION f_exp     CALL append_element("exp(",TRUE)
    ON ACTION f_logn    CALL append_element("logn(",TRUE)
    ON ACTION f_mod     CALL append_element("mod(",TRUE)
    ON ACTION f_rand    CALL append_element("rand(",TRUE)
    ON ACTION f_rad     CALL append_element("rad(",TRUE)
    ON ACTION f_deg     CALL append_element("deg(",TRUE)
    ON ACTION f_iif     CALL append_element("iif(",TRUE)
    ON ACTION f_abs     CALL append_element("abs(",TRUE)

    ON ACTION copy_result ATTRIBUTES(ACCELERATOR="Control-U")
       IF rec.res IS NOT NULL THEN
          LET rec.var_value = rec.res
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
       CALL libformula.evaluate(rec.src) RETURNING rec.sta, rec.res
       LET rec.msg = IIF(rec.sta==0,NULL,getErrorMessage(rec.sta))

    ON ACTION close
       EXIT DIALOG

    END DIALOG

    CALL libformula.finalize()

END MAIN

FUNCTION append_element(p STRING, s BOOLEAN) RETURNS ()
    DEFINE b base.StringBuffer,
           sels,sele,tmp, ilen SMALLINT
    IF s THEN
       LET p = " ", p, " "
    END IF
    LET b = base.StringBuffer.create()
    LET ilen = rec.src.getLength()
    LET sels = fgl_dialog_getcursor()
    LET sele = fgl_dialog_getselectionend()
    IF sels > sele THEN
       LET tmp = sele
       LET sele = sels
       LET sels = tmp
    END IF
    CALL b.append(rec.src)
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
    LET rec.src = b.toString()
    CALL fgl_dialog_setselection( sels, sele )
END FUNCTION

FUNCTION sync_var_fields(x INTEGER) RETURNS ()
    IF x>0 THEN
       LET rec.var_name = varlist[x].aname
       LET rec.var_value = libformula.getVariable(rec.var_name)
    ELSE
       LET rec.var_name = NULL
       LET rec.var_value = NULL
    END IF
END FUNCTION

FUNCTION sync_var_list() RETURNS ()
    CALL libformula.getVariableList(varlist)
END FUNCTION
