all : ok

ok :
	cvs -d:pserver:anonymous:@gxp.cvs.sourceforge.net:/cvsroot/gxp login
	cvs -z3 -d:pserver:anonymous@gxp.cvs.sourceforge.net:/cvsroot/gxp co -P gxp3
	touch $@
