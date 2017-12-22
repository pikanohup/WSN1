GEN = SampleMsg.java CommandMsg.java Constants.java

CONSTANTS = DEFAULT_INTERVAL AM_SAMPLE_MSG AM_COMMAND_MSG

all: oscilloscope.jar

oscilloscope.jar: Oscilloscope.class
	jar cf $@ *.class

SampleMsg.java: ../BaseStation/Msg.h
	mig -target=null -java-classname=SampleMsg java ../BaseStation/Msg.h SampleMsg -o $@

ControlMsg.java: ../BaseStation/Msg.h
	mig -target=null -java-classname=ControlMsg java ../BaseStation/Msg.h ControlMsg -o $@

Constants.java: ../BaseStation/Msg.h
	ncg -target=null -java-classname=Constants java ../BaseStation/Msg.h $(CONSTANTS) -o $@

Oscilloscope.class: $(wildcard *.java) $(GEN)
	javac *.java

clean:
	rm -f *.class $(GEN)

veryclean: clean
	rm oscilloscope.jar
