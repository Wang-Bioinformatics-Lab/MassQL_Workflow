#!/usr/bin/env nextflow
nextflow.enable.dsl=2

params.input_spectra = 'data/data' // We assume we pass it a folder with spectra files
params.query = "QUERY scaninfo(MS2DATA)"
params.parallel_files = 'YES'
params.extract = 'YES'
params.extractnaming = 'condensed' //condensed means it is mangled, original means the original mzML filenames
params.maxfilesize = "3000" // Default 3000 MB
params.max_extracted_scans = "10000" // Default 10000 scans

params.cache = "feather" // feather means it will cache, otherwise it will not
params.massql_cache_directory = "data/cache" // These are feather caches

// Workflow Boiler Plate
params.OMETAPARAM_YAML = "job_parameters.yaml"

// Downloading Files
params.download_usi_filename = params.OMETAPARAM_YAML // This can be changed if you want to run locally
params.cache_directory = "data/cache" // These are raw data caches

params.publishdir = "$baseDir"
TOOL_FOLDER = "$baseDir/bin"


process validateQuery {
    publishDir "$params.publishdir/nf_output/validation", mode: 'copy'

    conda "$TOOL_FOLDER/conda_env.yml"

    input:
    val(query)

    output:
    file "validated_query.txt" optional true

    script:
    """
    python $TOOL_FOLDER/validate_query.py \
    "$query" \
    validated_query.txt
    """
}

// downloading all the files
process prepInputFiles {
    //publishDir "$params.input_spectra", mode: 'copyNoFollow' // Warning, this is kind of a hack, it'll copy files back to the input folder
    
    conda "$TOOL_FOLDER/conda_env.yml"

    input:
    file input_parameters
    file cache_directory
    file input_spectra_folder

    output:
    val true
    // Here we likely need to output the individual files from the input spectra folder to get to the next
    file "${input_spectra_folder}/**"

    """
    python $TOOL_FOLDER/downloadpublicdata/bin/download_public_data_usi.py \
    $input_parameters \
    $input_spectra_folder \
    output_summary.tsv \
    --cache_directory $cache_directory \
    --existing_dataset_directory /data/datasets/server
    """
}

// This is the parallel run that will run on the cluster
process queryData {
    errorStrategy 'ignore'
    time '4h'
    //maxRetries 3

    //memory { 6.GB * task.attempt }
    //memory 12.GB

    conda "$TOOL_FOLDER/conda_env.yml"

    input:
    tuple val(filepath), val(mangled_output_filename), file(input_spectrum)

    output:
    file "*_output.tsv" optional true
    file "*_extract.json" optional true

    script:
    def extractflag = params.extract == 'YES' ? "--extract_json ${mangled_output_filename}_extract.json" : ''
    """
    python $TOOL_FOLDER/msql_cmd.py \
        "$input_spectrum" \
        "${params.query}" \
        --output_file "${mangled_output_filename}_output.tsv" \
        --original_path "$filepath" \
        --cache $params.cache \
        --cache_dir $params.massql_cache_directory \
        $extractflag \
        --maxfilesize $params.maxfilesize
    """
}

process queryData2 {
    errorStrategy 'ignore'
    maxForks 1
    time '4h'
    
    //publishDir "$params.publishdir/nf_output/msql_temp", mode: 'copy'
    conda "$TOOL_FOLDER/conda_env.yml"
    
    input:
    tuple val(filepath), val(mangled_output_filename), file(input_spectrum)

    output:
    file "*_output.tsv" optional true
    file "*_extract.json" optional true

    script:
    def extractflag = params.extract == 'YES' ? "--extract_json ${mangled_output_filename}_extract.json" : ''
    """
    python $TOOL_FOLDER/msql_cmd.py \
        "$input_spectrum" \
        "${params.query}" \
        --output_file "${mangled_output_filename}_output.tsv" \
        --original_path "$filepath" \
        --cache $params.cache \
        --cache_dir $params.massql_cache_directory \
        $extractflag \
        --maxfilesize $params.maxfilesize
    """
}

// Merging the results, 100 results at a time, and then doing a full merge
process formatResultsMergeRounds {
    publishDir "$params.publishdir/nf_output/msql", mode: 'copy'
    cache false

    //errorStrategy 'ignore'
    errorStrategy { task.attempt <= 10  ? 'retry' : 'terminate' }
    conda "$TOOL_FOLDER/conda_env.yml"
    
    input:
    file "results/*" 

    output:
    file "merged_tsv/*" optional true

    """
    mkdir merged_tsv
    python $TOOL_FOLDER/merged_results.py \
    results \
    --output_tsv_prefix merged_tsv/merged_tsv
    """
}



// Merging the JSON in rounds, 100 files at a time
process formatExtractedSpectraRounds {
    publishDir "$params.publishdir/nf_output/extracted", mode: 'copy'
    cache false
    errorStrategy 'ignore'

    conda "$TOOL_FOLDER/conda_env.yml"
    
    input:
    file "json/*" 

    output:
    file "extracted_mzML/*" optional true
    file "extracted_mgf/*" optional true
    file "extracted_json/*" optional true
    file "extracted_tsv/*" optional true 

    """
    mkdir extracted_mzML
    mkdir extracted_mgf
    mkdir extracted_json
    mkdir extracted_tsv
    python $TOOL_FOLDER/merged_extracted.py \
    json \
    extracted_mzML \
    extracted_mgf \
    extracted_json \
    --output_tsv_prefix extracted_tsv/extracted_tsv \
    --naming $params.extractnaming
    """
}


// Extracting the spectra
// process formatExtractedSpectra {
//     publishDir "$params.publishdir/nf_output/extracted", mode: 'copy'
//     cache false
//     errorStrategy 'ignore'

//     input:
//     file "input_merged.json" from _query_extract_results_merged_ch

//     output:
//     file "extracted_mzML" optional true
//     file "extracted_mgf" optional true
//     file "extracted.tsv" optional true
//     file "extracted_json" optional true into _extracted_json_ch

//     """
//     mkdir extracted_mzML
//     mkdir extracted_mgf
//     mkdir extracted_json
//     python $TOOL_FOLDER/merged_extracted.py \
//     input_merged.json \
//     extracted_mzML \
//     extracted_mgf \
//     extracted_json \
//     extracted.tsv 
//     """
// }

// process summarizeExtracted {
//     publishDir "$params.publishdir/nf_output/summary", mode: 'copy'
//     cache false
//     echo true
//     errorStrategy 'ignore'
    
//     input:
//     file(extracted_json) from _extracted_json_ch

//     output:
//     file "summary_extracted.html" optional true

//     """
//     python $TOOL_FOLDER/summarize_extracted.py \
//     $extracted_json \
//     summary_extracted.html
//     """
// }



process summarizeResults {
    publishDir "$params.publishdir/nf_output/summary", mode: 'copy'
    cache false
    errorStrategy 'ignore'

    conda "$TOOL_FOLDER/conda_env.yml"

    input:
    file(merged_results)

    output:
    file "summary.html" optional true

    """
    python $TOOL_FOLDER/summarize_results.py \
    $merged_results \
    summary.html
    """
}



workflow {

    // Validate the query
    validateQuery(params.query)

    // Downloading all files via USI
    input_spectra_ch = Channel.fromPath(params.input_spectra)
    usi_download_ch = Channel.fromPath(params.download_usi_filename)
    (_, _spectra_ch) = prepInputFiles(usi_download_ch, Channel.fromPath(params.cache_directory), input_spectra_ch)
    _spectra_ch = _spectra_ch.flatten()
    
    // Mapping the original filenames so we can display and have provenance
    _spectra_ch2 = _spectra_ch.map { file -> tuple(file, file.toString().replaceAll("/", "_").replaceAll(" ", "_"), file) }

    if(params.parallel_files == "YES"){
        (_query_results_ch, _query_extract_results_ch) = queryData(_spectra_ch2)
    }
    else{
        (_query_results_ch, _query_extract_results_ch) = queryData2(_spectra_ch2)
    }

    _merged_temp_summary_ch = formatResultsMergeRounds(_query_results_ch.collate( 100 ))
 
    _query_results_merged_ch = _merged_temp_summary_ch.collectFile(name: "merged_query_results.tsv", storeDir: "$params.publishdir/nf_output/msql", keepHeader: true)


    if(params.extract == "YES"){
        (_, _, _, _extracted_summary_ch) = formatExtractedSpectraRounds(_query_extract_results_ch.collate( 100 ))

        // Once we've done this, then we'lll do the actual merge
        _extracted_summary_ch.collectFile(name: "extracted.tsv", storeDir: "$params.publishdir/nf_output/extracted", keepHeader: true)
    }

    summarizeResults(_query_results_merged_ch)
}