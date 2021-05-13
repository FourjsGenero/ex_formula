FORMS=\
 formula_demo.42f

PROGMOD=\
 liblexer.42m \
 libformula.42m \
 formula_demo.42m

all: $(PROGMOD) $(FORMS)

%.42f: %.per
	fglform -M $<

%.42m: %.4gl
	fglcomp -Wall -M $<

run:: all
	fglrun formula_demo.42m

test-libformula::
	fglcomp -D TEST -D DEBUG -M libformula.4gl
	mv libformula.42m libformula_test.42m
	fglrun libformula_test.42m

test-liblexer::
	fglcomp -D TEST -D DEBUG -M liblexer.4gl
	mv liblexer.42m liblexer_test.42m
	fglrun liblexer_test.42m

clean::
	rm -f *.42?
