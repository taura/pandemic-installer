#
# a Makefile that pings clients of the specified
# address range.  if a client responds, it creates
# a file under /tmp/USER/TIMESTAMP/ping_result/ADDRESS,
# and show their addresses
#

address_prefix=10.0.3.
last_octet_begin=100
last_octet_end=199

out_dir:=/tmp/$(USER)/$(shell date +%Y-%m-%d-%H-%M-%S-%N)/ping_result
last_octets:=$(shell seq $(last_octet_begin) $(last_octet_end))
all_pings:=$(addprefix $(out_dir)/$(address_prefix),$(last_octets))

# all_pings is a space separated list of IP addresses to ping.
# e.g., 10.0.3.100 10.0.3.101 10.0.3.102 ... 10.0.3.199
#

# show their addresses
all : $(all_pings)
	ls -1 $(out_dir)/

$(all_pings) : $(out_dir)/% : $(out_dir)
	if ping -c 1 -W 1 $* > /dev/null; then touch $@ ; fi

$(out_dir) : 
	mkdir -p $@

