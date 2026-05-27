run:
	nextflow run ./nf_workflow.nf -resume \
	-c nextflow.config

# Build the Rust "fast" engine as a static musl binary and refresh the
# committed copy at MassQueryLanguage_Rust/bin/massql_rust. That copy lives in
# (and is checked into) the private Rust submodule; bin/massql_rust is a symlink
# to it, which is what the fast engine path invokes.
# Requires: rustup target add x86_64-unknown-linux-musl
build_rust:
	cd MassQueryLanguage_Rust && \
	cargo build --release -p massql-cli --target x86_64-unknown-linux-musl
	cp MassQueryLanguage_Rust/target/x86_64-unknown-linux-musl/release/massql MassQueryLanguage_Rust/bin/massql_rust
	chmod +x MassQueryLanguage_Rust/bin/massql_rust

run_test:
	nextflow run nf_workflow.nf -resume \
	-c nextflow_test.config \
	--parallel_files "YES" \
	--extract "NO" \
	--maxfilesize 100 \
	--cache_dir "${PWD}/data/cache" \
	--input_spectra "${PWD}/data/data" \
	--query "QUERY scaninfo(MS2DATA)"

run_test_fast:
	nextflow run nf_workflow.nf -resume \
	-c nextflow_test.config \
	--massql_engine "fast" \
	--parallel_files "YES" \
	--extract "NO" \
	--maxfilesize 100 \
	--cache_dir "${PWD}/data/cache" \
	--input_spectra "${PWD}/data/data" \
	--query "QUERY scaninfo(MS2DATA)"


run_usi_test:
	nextflow run nf_workflow.nf -resume \
	-c nextflow_test.config \
	--parallel_files "YES" \
	--extract "NO" \
	--maxfilesize 100 \
	--download_usi_filename "${PWD}/data/test_usi_list.tsv" \
	--cache_dir "${PWD}/data/cache" \
	--query "QUERY scaninfo(MS2DATA)"