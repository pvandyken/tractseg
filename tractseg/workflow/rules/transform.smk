def with_suffix(path, suffix):
    path = Path(path)
    return path.parent / (path.name.split(".")[0] + suffix)

rule get_shells_from_bvals:
    input:
        bval=with_suffix(inputs["dwi"].path, ".bval")
    output:
        json=temp(work/f"get_shells_from_bvals/{uid}.shells.json"),
    group:
        "subj"
    container:
        config["singularity"]["python"]
    script:
        "../scripts/get_shells_from_bvals.py"

rule get_avg_b0:
    input:
        dwi=inputs["dwi"].path,
        shells=rules.get_shells_from_bvals.output[0],
    output:
        avgshell=temp(work/f"get_b0/{uid}.nii.gz"),
    group:
        "subj"
    container:
        config["singularity"]["python"]
    params:
        bval="0",
    script:
        "../scripts/get_shell_avg.py"

rule run_synthSR:
    input:
        nii=rules.get_avg_b0.output
    output:
        out_nii=temp(work/f"run_synthsr/{uid}.nii.gz"),
    threads: 8
    group:
        "subj"
    log:
        bids(
            root="code/logs",
            suffix="run_synthSR.txt",
            **inputs["dwi"].wildcards,
        ),
    container:
        config["singularity"]["synthsr"]
    shadow:
        "minimal"
    resources:
        runtime=5,
    shell:
        "python /SynthSR/scripts/predict_command_line.py "
        "--cpu --threads {threads} "
        "{input} {output} &> {log}"


rule reslice_synthSR_b0:
    input:
        ref=rules.get_avg_b0.output,
        synthsr=rules.run_synthSR.output,
    output:
        synthsr=temp(bids(
            root=work,
            suffix="b0SynthSRresliced.nii.gz",
            datatype="dwi",
            desc="moco",
            **inputs["dwi"].wildcards,
        )),
    container:
        config["singularity"]["itksnap"]
    group:
        "subj"
    shell:
        "c3d {input.ref} {input.synthsr} -reslice-identity -o {output.synthsr}"

rule reg_dwi_to_mni:
    input:
        t1wsynth=mni_template,
        avgb0synth=rules.reslice_synthSR_b0.output,
        avgb0=rules.get_avg_b0.output,
    output:
        xfm_ras=temp(bids(
            root=work,
            datatype="transforms",
            from_="dwi",
            to="T1w",
            type_="ras",
            suffix="xfm.txt",
            **inputs["dwi"].wildcards,
        )),
    container:
        config["singularity"]["itksnap"]
    group:
        "subj"
    log:
        bids(
            root="code/logs",
            suffix="reg_b0_to_t1.txt",
            datatype="dwi",
            **inputs["dwi"].wildcards,
        ),
    threads: 8
    resources:
        runtime=2,
    params:
        general_opts="-d 3",
        rigid_opts=(
            "-m NMI -a -dof 6 -ia-{rigid_dwi_t1_init} -n {rigid_dwi_t1_iters}"
        ).format(
            rigid_dwi_t1_init=config["rigid_dwi_t1_init"],
            rigid_dwi_t1_iters=config["rigid_dwi_t1_iters"],
        ),
    shell:
        """
        greedy -threads {threads} {params.general_opts} {params.rigid_opts} \\
            -i {input.t1wsynth} {input.avgb0synth} -o {output.xfm_ras} \\
            &> {log}
        """

rule convert_xfm_ras2itk:
    input:
        xfm_ras=rules.reg_dwi_to_mni.output.xfm_ras,
    output:
        xfm_itk=bids(
            out,
            datatype="xfm",
            from_="dwi",
            to="MNI152NLin6Asym",
            type_="itk",
            suffix="xfm.txt",
            **inputs["dwi"].wildcards,
        ),
    container:
        config["singularity"]["itksnap"]
    group:
        "subj"
    shell:
        "c3d_affine_tool {input.xfm_ras} -oitk {output.xfm_itk}"

rule get_mif:
    input:
        dwi=inputs["dwi"].path,
        bval=with_suffix(inputs["dwi"].path, ".bval"),
        bvec=with_suffix(inputs["dwi"].path, ".bvec"),
    output:
        temp(work/f"get_mif/{uid}.mif")
    group:
        "subj"
    shell:
        """
        mrconvert {input.dwi} -q -fslgrad {input.bvec} {input.bval} {output}
        """

rule apply_transform:
    input:
        img=rules.get_mif.output,
        mask=inputs["mask"].path,
        txf=rules.convert_xfm_ras2itk.output,
        ref=mni_template,
    output:
        dwi=bids(
            out,
            datatype="dwi",
            space="MNI152NLin6Asym",
            suffix="dwi.mif",
            **inputs["dwi"].wildcards,
        ),
        mask=bids(
            out,
            datatype="dwi",
            space="MNI152NLin6Asym",
            desc="brain",
            suffix="mask.mif",
            **inputs["dwi"].wildcards,
        ),
    resources:
        runtime=5,
    group:
        "subj"
    shadow: "minimal"
    shell:
        """
        transformconvert -q {input.txf} itk_import txf.mat
        mrtransform -q {input.img} \\
            -linear txf.mat -template {input.ref} \\
            -reorient_fod no \\
            {output.dwi}
        mrtransform -q {input.mask} \\
            -linear txf.mat -template {input.ref} \\
            {output.mask}
        """