run:
	nextflow run ./nf_workflow.nf -resume \
	-c nextflow.config

run_test:
	nextflow run nf_workflow.nf -resume \
	-c nextflow_test.config \
	--parallel_files "YES" \
	--extract "NO" \
	--maxfilesize 100 \
	--cache_dir "${PWD}/data/cache"


run_usi_test:
	nextflow run nf_workflow.nf -resume \
	-c nextflow_test.config \
	--parallel_files "YES" \
	--extract "NO" \
	--maxfilesize 100 \
	--download_usi_filename "${PWD}/data/test_usi_list.tsv" \
	--cache_dir "${PWD}/data/cache"