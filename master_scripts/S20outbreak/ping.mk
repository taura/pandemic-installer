address_prefix=10.0.3.
last_octet_begin=100
last_octet_end=199

out_dir:=/tmp/$(USER)/$(shell date +%Y-%m-%d-%H-%M-%S-%N)/ping_result
last_octets:=$(shell seq $(last_octet_begin) $(last_octet_end))
all_pings:=$(addprefix $(out_dir)/$(address_prefix),$(last_octets))

all : $(all_pings)
	ls -1 $(out_dir)/

$(all_pings) : $(out_dir)/% : $(out_dir)
	if ping -c 1 -W 1 $* > /dev/null; then touch $@ ; fi

$(out_dir) : 
	mkdir -p $@

