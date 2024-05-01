rule sample_parameter_map:
    input:
        param=inputs["param"].path,
        segmentation=rules.transform_to_sample_space.output[0]
    output:
        bids(
            out,
            atlas="tractseg",
            suffix="sampled.mat",
            **inputs["param"].wildcards,
        )
    group: "sampling"
    resources:
        mem_mb=8000,
        runtime=4,
    container: config["singularity"]["python"]
    script: "../scripts/sample.py"