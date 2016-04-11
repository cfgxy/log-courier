.PHONY: prepare fix_version setup_root all log-courier gem gem_plugins push_gems test test_go test_rspec doc profile benchmark jrprofile jrbenchmark clean

MAKEFILE := $(word $(words $(MAKEFILE_LIST)),$(MAKEFILE_LIST))
GOPATH := $(patsubst %/,%,$(dir $(abspath $(MAKEFILE))))
export GOPATH := $(GOPATH)

TAGS :=
BINS := bin/log-courier bin/lc-tlscert bin/lc-admin
GOTESTS := log-courier lc-tlscert lc-admin lc-lib/...
TESTS := spec/courier_spec.rb spec/tcp_spec.rb spec/gem_spec.rb

ifneq (,$(findstring curvekey,$(MAKECMDGOALS)))
with := zmq4
endif

ifeq ($(with),zmq3)
TAGS := $(TAGS) zmq zmq_3_x
TESTS := $(TESTS) spec/plainzmq_spec.rb
endif
ifeq ($(with),zmq4)
TAGS := $(TAGS) zmq zmq_4_x
BINS := $(BINS) bin/lc-curvekey
GOTESTS := $(GOTESTS) lc-curvekey
TESTS := $(TESTS) spec/plainzmq_spec.rb spec/zmq_spec.rb
endif

ifneq ($(implyclean),yes)
LASTTAGS := $(shell cat .Makefile.tags 2>/dev/null)
ifneq ($(LASTTAGS),$(TAGS))
IMPLYCLEAN := $(shell $(MAKE) implyclean=yes clean)
SAVETAGS := $(shell echo "$(TAGS)" >.Makefile.tags)
endif
endif

all: | log-courier

log-courier: | $(BINS)

gem: | fix_version
	gem build log-courier.gemspec

gem_plugins: | fix_version
	gem build logstash-input-courier.gemspec
	gem build logstash-output-courier.gemspec

push_gems: | gem gem_plugins
	build/push_gems

test_go: | all
	go get -d -tags "$(TAGS)" $(GOTESTS)
	go test -tags "$(TAGS)" $(GOTESTS)

test_rspec: | all vendor/bundle/.GemfileModT
	bundle exec rspec $(TESTS)

jrtest_rspec: | all vendor/bundle/.GemfileJRubyModT
	jruby -G vendor/bundle/jruby/1.9/bin/rspec $(TESTS)

test: | test_go test_rspec

selfsigned: | bin/lc-tlscert
	bin/lc-tlscert

curvekey: | bin/lc-curvekey
	bin/lc-curvekey

doc:
	@npm --version >/dev/null || (echo "'npm' not found. You need to install node.js.")
	@npm install doctoc >/dev/null || (echo "Failed to perform local install of doctoc.")
	@node_modules/.bin/doctoc README.md
	@for F in docs/*.md docs/codecs/*.md; do node_modules/.bin/doctoc $$F; done

profile: | all vendor/bundle/.GemfileModT
	bundle exec rspec spec/profile_spec.rb

benchmark: | all vendor/bundle/.GemfileModT
	bundle exec rspec spec/benchmark_spec.rb

vendor/bundle/.GemfileModT: Gemfile
	bundle install --path vendor/bundle
	@touch $@

jrprofile: | all vendor/bundle/.GemfileJRubyModT
	jruby --profile -G vendor/bundle/jruby/1.9/bin/rspec spec/benchmark_spec.rb

jrbenchmark: | all vendor/bundle/.GemfileJRubyModT
	jruby -G vendor/bundle/jruby/1.9/bin/rspec spec/benchmark_spec.rb

vendor/bundle/.GemfileJRubyModT: Gemfile
	jruby -S bundle install --path vendor/bundle
	@touch $@

clean:
	go clean -i ./...
ifneq ($(implyclean),yes)
ifneq ($(keepgoget),yes)
	rm -rf src/github.com
endif
	rm -rf vendor/bundle
	rm -f Gemfile.lock
	rm -f *.gem
	rm -f *.rpm
endif

fix_version:
	build/fix_version "${FIX_VERSION}"

setup_root:
	build/setup_root

prepare: | fix_version setup_root
	@go version >/dev/null || (echo "Go not found. You need to install Go version 1.2-1.6: http://golang.org/doc/install"; false)
	@go version | grep -q 'go version go1.[23456]' || (echo "Go version 1.2-1.6, you have a version of Go that is not supported."; false)
	@echo "GOPATH: $${GOPATH}"

bin/%: prepare
	go get -d -tags "$(TAGS)" $*
	go install -tags "$(TAGS)" $*


build/empty: | build
	mkdir $@




.PHONY: rpm
rpm: AFTER_INSTALL=pkg/centos/after-install.sh
rpm: BEFORE_INSTALL=pkg/centos/before-install.sh
rpm: BEFORE_REMOVE=pkg/centos/before-remove.sh
rpm: PREFIX=/opt/log-courier
rpm: VERSION=1.8.2
rpm: all build/empty
	fpm -f -s dir -t $@ -n log-courier -v $(VERSION) \
		--architecture native \
		--replaces lumberjack \
		--description "a log shipping tool" \
		--url "https://github.com/elasticsearch/log-courier" \
		--after-install $(AFTER_INSTALL) \
		--before-install $(BEFORE_INSTALL) \
		--before-remove $(BEFORE_REMOVE) \
		--config-files /etc/log-courier.conf \
		--depends daemonize \
		./bin/log-courier=$(PREFIX)/bin/ \
		./bin/lc-tlscert=$(PREFIX)/bin/ \
		./bin/lc-admin=$(PREFIX)/bin/ \
		./docs/examples/example-confd.conf=/etc/log-courier.conf \
		./build/etc=/ \
		./build/empty/=/etc/log-courier.d/ \
		./build/empty/=/var/lib/log-courier/ \
		./build/empty/=/var/log/log-courier/ \

