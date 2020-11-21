PROJ := video_frame

TB_SW_SOURCES += main.c

WRITE_VCD := 1

include ../core.mk

# RGBS post processing to PNG

rgbs.log: $(PROJ).vvp
	vvp $<

screen.png: rgbs.log process_rgbs.py
	./process_rgbs.py $<
