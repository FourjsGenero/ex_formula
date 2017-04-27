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
