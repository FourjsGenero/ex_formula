FORMS=\
 formula_demo.42f

PROGMOD=\
 libformula.42m \
 formula_demo.42m

all: $(PROGMOD) $(FORMS)

%.42f: %.per
	fglform -M $<

%.42m: %.4gl
	fglcomp -M $<

run:: all
	fglrun formula_demo.42m

test::
	fglcomp -D TEST -M libformula.4gl
	mv libformula.42m libformula_test.42m
	fglcomp -M libformula.4gl
	fglrun libformula_test.42m

clean::
	rm -f *.42?
