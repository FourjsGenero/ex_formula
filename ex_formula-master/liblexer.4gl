--
-- WARNINGS
-- * Supports any single-byte charset (like ISO88591) or UTF-8 with FGL_LENGTH_SEMANTICS=CHAR
-- * Identifiers can only be ASCII based ([_a-zA-Z][0-9_a-zA-Z])
--

PUBLIC CONSTANT SL_TOKID_END         = 100
PUBLIC CONSTANT SL_TOKID_BLANK       = 1
PUBLIC CONSTANT SL_TOKID_IDENT       = 2
PUBLIC CONSTANT SL_TOKID_STRING      = 3
PUBLIC CONSTANT SL_TOKID_NUMBER      = 4
PUBLIC CONSTANT SL_TOKID_OTHER       = 5
PUBLIC CONSTANT SL_TOKID_INV_STRING  = -1
PUBLIC CONSTANT SL_TOKID_INV_NUMBER  = -2
PUBLIC CONSTANT SL_TOKID_INV_IDENT   = -3
PUBLIC CONSTANT SL_TOKID_INV_BLANK   = -4

PUBLIC TYPE t_lexer_tokens DYNAMIC ARRAY OF RECORD
            tokid SMALLINT,
            token STRING,
            igncase BOOLEAN,
            act SMALLINT -- -1 stop, 1 warning ...
       END RECORD

PRIVATE DEFINE init_count SMALLINT

&ifdef TEST

MAIN

    CALL initialize()

    IF length("é日") != 2 THEN
       DISPLAY "ERROR: Make sure locale is UTF-8 and FGL_LENGTH_SEMANTICS=CHAR!"
       EXIT PROGRAM 1
    END IF

    CALL test_extract_number()
    CALL test_extract_string()
    CALL test_extract_identifier()
    CALL test_extract_blank()

    DISPLAY parse_string(NULL)
    DISPLAY parse_string(" ")
    DISPLAY parse_string(" abc ")
    DISPLAY parse_string(" abc aaa_123 ")
    DISPLAY parse_string(" abc 'def ")
    DISPLAY parse_string(" abc 'd''ef ")
    DISPLAY parse_string(" abc 123aaa ")
    DISPLAY parse_string("123+456")
    DISPLAY parse_string("123 / 456 abc")
    DISPLAY parse_string("123 * 456 abc")
    DISPLAY parse_string("123 - 456 abc")
    DISPLAY parse_string("123 + 456 abc")
    DISPLAY parse_string("(123)+(456)abc")
    DISPLAY parse_string(" 'abc' ")
    DISPLAY parse_string(" uniON ")
    DISPLAY parse_string(" ; ")

    DISPLAY parse_string("SELECT * FROM tab WHERE col='abcdef' NOT NULL UNION SELECT * FROM tab")

    CALL finalize()

    --CALL test_file("sql_samples.txt")

END MAIN

{
PRIVATE FUNCTION test_file(fn STRING) RETURNS ()
    DEFINE ch base.Channel,
           sqlcmd STRING
    LET ch = base.Channel.create()
    CALL ch.openFile(fn,"r")
    WHILE TRUE
        LET sqlcmd = ch.readLine()
        IF ch.isEof() THEN EXIT WHILE END IF
        DISPLAY "\n==== ", sqlcmd
        DISPLAY parse_string(sqlcmd)
    END WHILE
END FUNCTION
}

PRIVATE FUNCTION test_extract_number()

    DISPLAY "\n==== extract numbers:"

    CALL _test_extract_number("0")
    CALL _test_extract_number("1")
    CALL _test_extract_number("124")
    CALL _test_extract_number(".34")
    CALL _test_extract_number(".00")
    CALL _test_extract_number(".1234")
    CALL _test_extract_number(".1234e10")
    CALL _test_extract_number("123.34")
    CALL _test_extract_number("123.34E10")
    CALL _test_extract_number("123.34e-123")
    CALL _test_extract_number("123.34E-123")
    CALL _test_extract_number("124")
    CALL _test_extract_number("123.34")
    CALL _test_extract_number("123.34 ")
    CALL _test_extract_number("123.34(")
    CALL _test_extract_number("123.34+")
    CALL _test_extract_number("123.34-")
    CALL _test_extract_number("123.34/")
    CALL _test_extract_number("123.34*")
    --
    CALL _test_extract_number(NULL)
    CALL _test_extract_number("+")
    CALL _test_extract_number("-")
    CALL _test_extract_number(".")
    CALL _test_extract_number("...")
    CALL _test_extract_number("abc")
    CALL _test_extract_number("0a")
    CALL _test_extract_number("1a")
    CALL _test_extract_number("124a")
    CALL _test_extract_number("123.34a")
    CALL _test_extract_number("123.34_")
END FUNCTION

PRIVATE FUNCTION _test_extract_number(str CHAR(40)) RETURNS ()
    DEFINE buf base.StringBuffer,
           tid, pos INTEGER,
           tok base.StringBuffer
    LET buf = base.StringBuffer.create()
    LET tok = base.StringBuffer.create()
    CALL buf.append(str)
    CALL extract_number(buf,1,tok) RETURNING tid, pos
    DISPLAY str, ":", tid, pos, " [",tok.toString(),"]"
END FUNCTION

PRIVATE FUNCTION test_extract_string() RETURNS ()

    DISPLAY "\n==== extract strings:"

    CALL _test_extract_string("''")             -- ''
    CALL _test_extract_string('""')             -- ""

    CALL _test_extract_string("'abc'")          -- 'abc'
    CALL _test_extract_string('"abc"')          -- "abc"

    CALL _test_extract_string("''''")           -- ''''
    CALL _test_extract_string('""""')           -- """"

    CALL _test_extract_string("'\\''")          -- '\''
    CALL _test_extract_string('"\\""')          -- "\""

    CALL _test_extract_string("'a''b''c'")      -- 'a''b''c'
    CALL _test_extract_string('"a""b""c"')      -- "a""b""c"

    CALL _test_extract_string("'a\\'b\\'c'")    -- 'a\'b\'c'
    CALL _test_extract_string('"a\\"b\\"c"')    -- "a\"b\"c"

    --
    CALL _test_extract_string(NULL)
    CALL _test_extract_string("'")
    CALL _test_extract_string('"')
    CALL _test_extract_string("a")
    CALL _test_extract_string("123")
    CALL _test_extract_string("abc")
    CALL _test_extract_string(" abc")
    CALL _test_extract_string(' "abc"')
    CALL _test_extract_string('"abcé日"')

END FUNCTION

PRIVATE FUNCTION _test_extract_string(str CHAR(40)) RETURNS ()
    DEFINE buf base.StringBuffer,
           tid, pos INTEGER,
           tok base.StringBuffer
    LET buf = base.StringBuffer.create()
    LET tok = base.StringBuffer.create()
    CALL buf.append(str)
    CALL extract_string(buf,1,tok) RETURNING tid, pos
    DISPLAY str, ":", tid, pos, " [",tok.toString(),"]"
END FUNCTION

PRIVATE FUNCTION test_extract_identifier() RETURNS ()

    DISPLAY "\n==== extract identifiers"

    CALL _test_extract_identifier("_")
    CALL _test_extract_identifier("a")
    CALL _test_extract_identifier("_a")
    CALL _test_extract_identifier("abc")
    CALL _test_extract_identifier("_abc")
    CALL _test_extract_identifier("abc123")
    CALL _test_extract_identifier("_abc123")
    CALL _test_extract_identifier("abc123(")
    CALL _test_extract_identifier("_abc123/")
    CALL _test_extract_identifier("abc123*")
    CALL _test_extract_identifier("_abc123+")
    CALL _test_extract_identifier("_abc123 ")
    --
    CALL _test_extract_identifier(NULL)
    CALL _test_extract_identifier("2")
    CALL _test_extract_identifier("2ab")
    CALL _test_extract_identifier("+2ab")
    CALL _test_extract_identifier("*2ab")
    CALL _test_extract_identifier(" 2ab")
END FUNCTION

PRIVATE FUNCTION _test_extract_identifier(str CHAR(40)) RETURNS ()
    DEFINE buf base.StringBuffer,
           tid, pos INTEGER,
           tok base.StringBuffer
    LET buf = base.StringBuffer.create()
    LET tok = base.StringBuffer.create()
    CALL buf.append(str)
    CALL extract_identifier(buf,1,tok) RETURNING tid, pos
    DISPLAY str, ":", tid, pos, " [",tok.toString(),"]"
END FUNCTION

PRIVATE FUNCTION test_extract_blank() RETURNS ()

    DISPLAY "\n==== extract blanks:"

    CALL _test_extract_blank(" ")
    CALL _test_extract_blank(" \t\r")
    CALL _test_extract_blank(" \t\r  \t \r \t")
    CALL _test_extract_blank(" abc")
    CALL _test_extract_blank(" 123")
    CALL _test_extract_blank(" \t\raa")

END FUNCTION

PRIVATE FUNCTION _test_extract_blank(str STRING) RETURNS ()
    DEFINE buf base.StringBuffer,
           tid, pos INTEGER,
           tok base.StringBuffer
    LET buf = base.StringBuffer.create()
    LET tok = base.StringBuffer.create()
    CALL buf.append(str)
    CALL extract_blank(buf,1,tok) RETURNING tid, pos
    DISPLAY str, ":", tid, pos
END FUNCTION

&endif

#---

PUBLIC FUNCTION initialize() RETURNS ()
    LET init_count = init_count+1
END FUNCTION

PUBLIC FUNCTION finalize() RETURNS ()
    LET init_count = init_count-1
END FUNCTION

#---

PRIVATE FUNCTION extract_number(
    buf base.StringBuffer,
    pos INTEGER,
    tok base.StringBuffer
) RETURNS (SMALLINT, INTEGER)
    DEFINE x INTEGER,
           dig_seen BOOLEAN,
           sgn_seen BOOLEAN,
           dec_seen BOOLEAN,
           exp_seen BOOLEAN,
           c CHAR(1)
    CALL tok.clear()
    LET x = pos - 1
    WHILE TRUE
        LET c = buf.getCharAt(x:=x+1)
        CASE
          WHEN (c=="e" OR c=="E") AND dig_seen AND NOT exp_seen
            LET exp_seen = TRUE
            CALL tok.append(c)
          WHEN (c=="+" OR c=="-") AND exp_seen AND NOT sgn_seen
            LET sgn_seen = TRUE
            CALL tok.append(c)
          WHEN c=="." AND NOT dec_seen
            LET dec_seen = TRUE
            CALL tok.append(c)
          WHEN c MATCHES "[0-9]"
            LET dig_seen = TRUE
            CALL tok.append(c)
          WHEN c MATCHES "[_a-zA-Z]"
            CALL tok.clear()
            RETURN SL_TOKID_INV_NUMBER, NULL
          OTHERWISE
            IF dig_seen THEN
               RETURN SL_TOKID_NUMBER, x
            ELSE
               CALL tok.clear()
               RETURN SL_TOKID_INV_NUMBER, NULL
            END IF
        END CASE
    END WHILE
    RETURN SL_TOKID_NUMBER, x
END FUNCTION

PRIVATE FUNCTION extract_string(
    buf base.StringBuffer,
    pos INTEGER,
    tok base.StringBuffer
) RETURNS (SMALLINT,INTEGER)
    DEFINE x INTEGER,
           delim CHAR(1),
           c, c2 CHAR(1)
    CALL tok.clear()
    LET c = buf.getCharAt(x:=pos)
    IF c IS NULL OR (c!="'" AND c!='"') THEN
       RETURN SL_TOKID_INV_STRING, NULL
    ELSE
       LET delim = c
       CALL tok.append(c)
    END IF
    WHILE TRUE
        LET c = buf.getCharAt(x:=x+1)
        CASE
          WHEN c==delim
            CALL tok.append(c)
            LET c2 = buf.getCharAt(x+1)
            LET x = x+1
            IF c2==delim THEN
               CALL tok.append(c2)
            ELSE
               RETURN SL_TOKID_STRING, x
            END IF
          WHEN c=="\\"
            CALL tok.append(c)
            LET c2 = buf.getCharAt(x+1)
            IF c2==delim THEN
               CALL tok.append(c2)
               LET x = x+1
            END IF
          WHEN c IS NULL
            CALL tok.clear()
            RETURN SL_TOKID_INV_STRING, NULL
          OTHERWISE
            CALL tok.append(c)
        END CASE
    END WHILE
    CALL tok.clear()
    RETURN SL_TOKID_INV_STRING, NULL
END FUNCTION

PRIVATE FUNCTION extract_identifier(
    buf base.StringBuffer,
    pos INTEGER,
    tok base.StringBuffer
) RETURNS (SMALLINT,INTEGER)
    DEFINE x INTEGER,
           c CHAR(1)
    CALL tok.clear()
    LET c = buf.getCharAt(x:=pos)
    IF c IS NULL OR c NOT MATCHES "[_a-zA-Z]" THEN
       RETURN SL_TOKID_INV_IDENT, NULL
    ELSE
       CALL tok.append(c)
    END IF
    WHILE TRUE
        LET c = buf.getCharAt(x:=x+1)
        IF c MATCHES "[0-9_a-zA-Z]" THEN
           CALL tok.append(c)
        ELSE
           EXIT WHILE
        END IF
    END WHILE
    RETURN SL_TOKID_IDENT, x
END FUNCTION

PRIVATE FUNCTION is_blank(c CHAR(1)) RETURNS BOOLEAN
    RETURN (c==ASCII(32) OR c==ASCII(9) OR c==ASCII(13) OR c==ASCII(10))
END FUNCTION

PRIVATE FUNCTION extract_blank(
    buf base.StringBuffer,
    pos INTEGER,
    tok base.StringBuffer
) RETURNS (SMALLINT,INTEGER)
    DEFINE x INTEGER,
           seen BOOLEAN,
           c CHAR(1)
    CALL tok.clear()
    LET x = pos-1
    WHILE TRUE
        LET c = buf.getCharAt(x:=x+1)
        IF is_blank(c) THEN
           LET seen = TRUE
           CALL tok.append(c)
        ELSE
           EXIT WHILE
        END IF
    END WHILE
    IF seen THEN
       RETURN SL_TOKID_BLANK, x
    ELSE
       CALL tok.clear()
       RETURN SL_TOKID_INV_BLANK, NULL
    END IF
END FUNCTION

PRIVATE FUNCTION _next_token(
    buf base.StringBuffer,
    pos INTEGER
) RETURNS (SMALLINT, INTEGER, STRING)
    DEFINE next_pos INTEGER,
           tokid SMALLINT,
           token base.StringBuffer,
           c CHAR(1)
    LET tokid = NULL
    IF pos > buf.getLength() THEN
       RETURN SL_TOKID_END, pos, NULL
    END IF
    LET token = base.StringBuffer.create()
    LET c = buf.getCharAt(pos)
    CASE
      WHEN is_blank(c)
        CALL extract_blank(buf, pos, token) RETURNING tokid, next_pos
      WHEN c == "'" OR c == '"'
        CALL extract_string(buf, pos, token) RETURNING tokid, next_pos
      WHEN c MATCHES "[0-9]" OR c MATCHES "[+-.][0-9]"
        CALL extract_number(buf, pos, token) RETURNING tokid, next_pos
      WHEN c MATCHES "[_a-zA-Z]"
        CALL extract_identifier(buf, pos, token) RETURNING tokid, next_pos
      OTHERWISE
        LET tokid = SL_TOKID_OTHER
        CALL token.append(c)
        LET next_pos = pos + 1
    END CASE
    RETURN tokid, next_pos, token.toString()
END FUNCTION

PUBLIC FUNCTION getNextToken(
    buf base.StringBuffer,
    pos INTEGER,
    ib BOOLEAN
) RETURNS (SMALLINT, INTEGER, STRING)
    DEFINE next_pos INTEGER,
           tokid SMALLINT,
           token STRING
    LET next_pos = pos
    CALL _next_token(buf,next_pos) RETURNING tokid, next_pos, token
    IF ib AND tokid = SL_TOKID_BLANK THEN
       CALL _next_token(buf,next_pos) RETURNING tokid, next_pos, token
    END IF
    RETURN tokid, next_pos, token
END FUNCTION

PRIVATE FUNCTION parse_string(str STRING) RETURNS SMALLINT
    DEFINE buf base.StringBuffer,
           pos INTEGER,
           tokid SMALLINT, token STRING
    LET buf = base.StringBuffer.create()
    CALL buf.append(str)
    LET pos = 1
    WHILE tokid != SL_TOKID_END
       CALL getNextToken(buf, pos, FALSE) RETURNING tokid, pos, token
&ifdef DEBUG
display pos, "  t=", tokid, " [", token, "]"
&endif
       IF tokid<0 THEN
          RETURN tokid
       END IF
    END WHILE
&ifdef DEBUG
display "last pos: ", pos, " length:", length(str)
&endif
    RETURN 0
END FUNCTION
