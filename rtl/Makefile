ifndef VERBOSE
VERBOSE = 0
endif
ifndef SIMULATOR
SIMULATOR = vsim
endif
ifndef SOURCES
SOURCES = \
	$(wildcard gobou/*.sv)  \
	$(wildcard renkon/*.sv) \
	$(wildcard ninjin/*.sv) \
	$(wildcard common/*.sv)
endif
ifndef TESTSUITE
TESTSUITE = \
	$(wildcard ../test/gobou/*.sv)  \
	$(wildcard ../test/renkon/*.sv) \
	$(wildcard ../test/ninjin/*.sv) \
	$(wildcard ../test/common/*.sv)
endif
ifndef INCLUDE
INCLUDE = $(shell git rev-parse --show-toplevel)/rtl/common
endif
ifndef DIST
DIST = ../dist
endif

############################################################
# Major Rules
############################################################

.PHONY: all test test-all clean dist dist-sub

all: $(SOURCES:.sv=.com) $(TESTSUITE:.sv=.com)

test: $(TARGET:.sv=.log)
test-all: $(TESTSUITE:.sv=.log)

$(TARGET:.sv=.log): $(DEPENDS:.sv=.com) $(MODULE:.sv=.com)
# $(TESTSUITE:.sv=.log): $(SOURCES:.sv=.com)

ci:
	@watchmedo shell-command -W -R \
	  -p "*.sv;*.svh" -c "$(MAKE) test diff" {../,../../test}

log:
	@nvim $(TARGET:.sv=.log)

com:
	@nvim $(TARGET:.sv=.com)

edit:
	@nvim -O $(TARGET) $(MODULE)

DIFF=diff -qs
diff:
	@$(DIFF) ../../data/$(notdir $(PWD))/output_$(MODULE:.sv=.dat) \
		 ../../data/$(notdir $(PWD))/true_$(MODULE:.sv=.dat)
ediff:
	@nvim -d ../../data/$(notdir $(PWD))/output_$(MODULE:.sv=.dat) \
		 ../../data/$(notdir $(PWD))/true_$(MODULE:.sv=.dat)

clean:
	rm -f $(MODULE:.sv=.com)
	rm -f $(DEPENDS:.sv=.com)
	rm -f $(SOURCES:.sv=.com)
	rm -f $(TARGET:.sv=.com) $(TARGET:.sv=.log)
	rm -f $(TESTSUITE:.sv=.com) $(TESTSUITE:.sv=.log)
	### vsim
	rm -rf work csrc
	rm -f vsim.wlf transcript
	rm -f vish_stacktrace.vstf
	### xsim
	rm -rf xsim.dir .Xil
	rm -f xvlog.log xvlog.pb
	rm -f xelab.log xsim*.log
	rm -f webtalk*.log hs_err_pid*.log
	rm -f *.jou *.pb *.wdb
	### vcs
	rm -rf *.com.daidir *.out.daidir
	rm -f default.cfg vcdplus.vpd vcs.key ucli.key
	### iverilog
	rm -f *.out

ifndef MODULE
dist:
	$(MAKE) -C common dist DIST=../$(DIST)
	$(MAKE) -C ninjin dist DIST=../$(DIST)
	$(MAKE) -C renkon dist DIST=../$(DIST)
	$(MAKE) -C gobou  dist DIST=../$(DIST)
else
dist:
	mkdir -p $(DIST)
	rsync -L -avz $(MODULE) $(DEPENDS) $(HEADERS) $(TARGET) $(DIST)
endif

############################################################
# Attributes Definition
############################################################

ifeq ($(VERBOSE),1)
  E = @true
  Q =
else
  E = @
  Q = @
endif

V_TARGET    = $(shell echo $* | tac -s/ | head -1)
ifeq ($(SIMULATOR),xsim)
  XVLOG_OPT = -sv -i $(INCLUDE) --verbose 2
  COMPILE   = xvlog $(XVLOG_OPT) $<
  XELAB_OPT = #-debug typical
  ELABORATE = xelab $(XELAB_OPT) $(V_TARGET) -s $(V_TARGET)_sim
  XSIM_OPT  = -R #$(XVLOG_OPT)
  SIMULATE  = xsim $(V_TARGET)_sim $(XSIM_OPT)
else
ifeq ($(SIMULATOR),vsim)
  VLOG_OPT  = -sv12compat +incdir+$(INCLUDE) -lint
  COMPILE   = (test -d work || vlib work) \
           && vlog $(VLOG_OPT) $<
  VSIM_OPT  = -c -do 'run -all; quit' $(VSIM_LIB)
  SIMULATE  = vsim $(V_TARGET) $(VSIM_OPT) | sed 's/^\# //'
else
ifeq ($(SIMULATOR),vcs)
  VCS_OPT   = -full64 -sverilog +incdir+$(INCLUDE) -R
  COMPILE   = true $<
  SIMULATE  = vcs $(VCS_OPT) -o $(V_TARGET).out $*.sv $(SOURCES)
else
ifeq ($(SIMULATOR),iverilog)
  IVER_OPT  = -g2012 -I $(INCLUDE)
  COMPILE   = iverilog $(IVER_OPT) -t null $<
  SIMULATE  = iverilog $(IVER_OPT) -o $(V_TARGET).out $(SOURCES) \
           && time ./$(V_TARGET).out
endif
endif
endif
endif

############################################################
# General Rules
############################################################

.SUFFIXES: .com .log .v .sv .vh .svh

.v.com:
	$(E) echo "  COMPILE (.v)      $<"
ifeq ($(VERBOSE),1)
	$(Q) $(COMPILE) 2>&1 | tee $@
else
	$(Q) $(COMPILE) > $@ 2>&1
endif

.sv.com:
	$(E) echo "  COMPILE (.sv)     $<"
ifeq ($(VERBOSE),1)
	$(Q) $(COMPILE) 2>&1 | tee $@
else
	$(Q) $(COMPILE) > $@ 2>&1
endif

.com.log:
ifeq ($(SIMULATOR),xsim)
	$(E) echo "  ELABORATE         $(V_TARGET)"
  ifeq ($(VERBOSE),1)
		$(Q) $(ELABORATE) 2>&1 | tee $@
  else
		$(Q) $(ELABORATE) > $@ 2>&1
  endif
	$(E) echo "  SIMULATE          $(V_TARGET)"
  ifeq ($(VERBOSE),1)
		$(Q) $(SIMULATE) 2>&1 | tee -a $@
  else
		$(Q) $(SIMULATE) >> $@ 2>&1
  endif
else
	$(E) echo "  SIMULATE          $(V_TARGET)"
  ifeq ($(VERBOSE),1)
		$(Q) $(SIMULATE) 2>&1 | tee $@
  else
		$(Q) $(SIMULATE) > $@ 2>&1
  endif
endif

