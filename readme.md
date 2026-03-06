# FoundationPose: Unified 6D Pose Estimation and Tracking of Novel Objects

[[Paper]](https://arxiv.org/abs/2312.08344) [[Website]](https://nvlabs.github.io/FoundationPose/)

This is the official implementation of our paper to be appeared in CVPR 2024 (Highlight)

Contributors: Bowen Wen, Wei Yang, Jan Kautz, Stan Birchfield

We present FoundationPose, a unified foundation model for 6D object pose estimation and tracking, supporting both model-based and model-free setups. Our approach can be instantly applied at test-time to a novel object without fine-tuning, as long as its CAD model is given, or a small number of reference images are captured. We bridge the gap between these two setups with a neural implicit representation that allows for effective novel view synthesis, keeping the downstream pose estimation modules invariant under the same unified framework. Strong generalizability is achieved via large-scale synthetic training, aided by a large language model (LLM), a novel transformer-based architecture, and contrastive learning formulation. Extensive evaluation on multiple public datasets involving challenging scenarios and objects indicate our unified approach outperforms existing methods specialized for each task by a large margin. In addition, it even achieves comparable results to instance-level methods despite the reduced assumptions.

<img src="assets/intro.jpg" width="70%">

**🤖 For ROS version, please check [Isaac ROS Pose Estimation](https://github.com/NVIDIA-ISAAC-ROS/isaac_ros_pose_estimation), which enjoys TRT fast inference and C++ speed up.**

\
**🥇 No. 1 on the world-wide [BOP leaderboard](https://bop.felk.cvut.cz/leaderboards/pose-estimation-unseen-bop23/core-datasets/) (as of 2024/03) for model-based novel object pose estimation.**

<img src="assets/bop.jpg" width="80%">

## Demos

Robotic Applications:

https://github.com/NVlabs/FoundationPose/assets/23078192/aa341004-5a15-4293-b3da-000471fd74ed

AR Applications:

https://github.com/NVlabs/FoundationPose/assets/23078192/80e96855-a73c-4bee-bcef-7cba92df55ca

Results on YCB-Video dataset:

https://github.com/NVlabs/FoundationPose/assets/23078192/9b5bedde-755b-44ed-a973-45ec85a10bbe

## Bibtex

```bibtex
@InProceedings{foundationposewen2024,
author        = {Bowen Wen, Wei Yang, Jan Kautz, Stan Birchfield},
title         = {{FoundationPose}: Unified 6D Pose Estimation and Tracking of Novel Objects},
booktitle     = {CVPR},
year          = {2024},
}
```

If you find the model-free setup useful, please also consider cite:

```bibtex
@InProceedings{bundlesdfwen2023,
author        = {Bowen Wen and Jonathan Tremblay and Valts Blukis and Stephen Tyree and Thomas M\"{u}ller and Alex Evans and Dieter Fox and Jan Kautz and Stan Birchfield},
title         = {{BundleSDF}: {N}eural 6-{DoF} Tracking and {3D} Reconstruction of Unknown Objects},
booktitle     = {CVPR},
year          = {2023},
}
```

## Data Preparation

A download script `download_data.sh` is provided to fetch all required data from Google Drive automatically. It installs [`gdown`](https://github.com/wkentaro/gdown) if not already present.

```bash
# Download model weights + demo data (default)
bash download_data.sh

# Download model weights only
bash download_data.sh --weights

# Download demo data only
bash download_data.sh --demo

# Download preprocessed reference views (needed for model-free setup)
bash download_data.sh --ref-views

# Download large-scale training data (~tens of GB, confirmation required)
bash download_data.sh --train

# Download everything
bash download_data.sh --all
```

Directories created by the script:

| Flag | Destination | Contents |
| ------ | ----------- | --------- |
| `--weights` | `weights/` | Refiner (`2023-10-28-18-33-37`) + Scorer (`2024-01-11-20-02-45`) |
| `--demo` | `demo_data/` | Demo scenes (mustard0, driller, …) |
| `--ref-views` | `ref_views/` | Preprocessed reference views for model-free setup |
| `--train` | `training_data/` | Large-scale synthetic training data |

> **Note:** Already-existing directories are skipped automatically. Remove the directory and re-run to force a fresh download.

## Env Setup Option 1: Docker

```bash
cd docker/
docker pull wenbowen123/foundationpose && docker tag wenbowen123/foundationpose foundationpose  # Or to build from scratch: docker build --network host -t foundationpose .
bash docker/run_container.sh
```

If it's the first time you launch the container, you need to build extensions. Run this command *inside* the Docker container.

```bash
bash build_all.sh
```

Later you can execute into the container without re-build.

```bash
docker exec -it foundationpose bash
```

For more recent GPU such as 4090, refer to [this](https://github.com/NVlabs/FoundationPose/issues/27).
In short, do the following:

```bash
docker pull shingarey/foundationpose_custom_cuda121:latest
```

Then modify the bash script to use this image instead of `foundationpose:latest`.

## Env Setup Option 2: Conda

> **Tested configuration:** Python 3.9 · PyTorch 2.0.0+cu118 · CUDA 11.8 · RTX 3090/4080/4090 (sm_86/sm_89)

### Prerequisites

| Requirement | Version | Check |
| ------------- | --------- | ------- |
| Anaconda / Miniconda | any | `conda --version` |
| CUDA 11.8 | at `/usr/local/cuda-11.8` | `ls /usr/local/cuda-11.8` |
| GCC 11 | at `/usr/bin/gcc-11` | `gcc-11 --version` |

### One-Command Setup

```bash
bash setup_conda_env.sh
```

This single script handles everything: conda env creation, all pip dependencies, NVDiffRast, PyTorch3D, Kaolin, C++/CUDA extension builds, and the conda activation script.

**Options:**

| Flag | Description |
| ------ | ------------- |
| `--name <env>` | Use a custom environment name (default: `foundationpose`) |
| `--skip-kaolin` | Skip Kaolin (not needed for model-based setup) |
| `--reinstall` | Remove the existing environment and start fresh (run from outside the env) |

After setup, activate the environment and run:

```bash
conda activate foundationpose
python run_demo.py
```

The script writes `etc/conda/activate.d/env_vars.sh` so the following variables are restored automatically on every `conda activate`:

| Variable | Value | Purpose |
| ---------- | ------- | --------- |
| `CUDA_HOME` | `/usr/local/cuda-11.8` | Point nvcc to CUDA 11.8 |
| `CC` / `CXX` | `/usr/bin/gcc-11` / `g++-11` | CUDA 11.8 supports GCC ≤ 11 |
| `TORCH_CUDA_ARCH_LIST` | auto-detected (e.g. `8.9` for RTX 4080) | Target GPU architecture |
| `LD_LIBRARY_PATH` | torch lib + cuda-11.8/lib64 | Runtime shared library lookup |

## Run Model-based Demo

The paths have been set in argparse by default. If you need to change the scene, you can pass the args accordingly. By running on the demo data, you should be able to see the robot manipulating the mustard bottle. Pose estimation is conducted on the first frame, then it automatically switches to tracking mode for the rest of the video. The resulting visualizations will be saved to the `debug_dir` specified in the argparse. (Note the first time running could be slower due to online compilation)

```python
python run_demo.py
```

<img src="assets/demo.jpg" width="50%">

Feel free to try on other objects (**no need to retrain**) such as driller, by changing the paths in argparse.

<img src="assets/demo_driller.jpg" width="50%">

## Run on Public Datasets (LINEMOD, YCB-Video)

For this you first need to download LINEMOD dataset and YCB-Video dataset.

To run model-based version on these two datasets respectively, set the paths based on where you download. The results will be saved to `debug` folder

```python
python run_linemod.py --linemod_dir /mnt/9a72c439-d0a7-45e8-8d20-d7a235d02763/DATASET/LINEMOD --use_reconstructed_mesh 0

python run_ycb_video.py --ycbv_dir /mnt/9a72c439-d0a7-45e8-8d20-d7a235d02763/DATASET/YCB_Video --use_reconstructed_mesh 0
```

To run model-free few-shot version. You first need to train Neural Object Field. `ref_view_dir` is based on where you download in the above "Data prepare" section. Set the `dataset` flag to your interested dataset.

```python
python bundlesdf/run_nerf.py --ref_view_dir /mnt/9a72c439-d0a7-45e8-8d20-d7a235d02763/DATASET/YCB_Video/bowen_addon/ref_views_16 --dataset ycbv
```

Then run the similar command as the model-based version with some small modifications. Here we are using YCB-Video as example:

```python
python run_ycb_video.py --ycbv_dir /mnt/9a72c439-d0a7-45e8-8d20-d7a235d02763/DATASET/YCB_Video --use_reconstructed_mesh 1 --ref_view_dir /mnt/9a72c439-d0a7-45e8-8d20-d7a235d02763/DATASET/YCB_Video/bowen_addon/ref_views_16
```

## Troubleshooting

- For more recent GPU such as 4090, refer to [this](https://github.com/NVlabs/FoundationPose/issues/27).

- For setting up on Windows, refer to [this](https://github.com/NVlabs/FoundationPose/issues/148).

- If you are getting unreasonable results, check [this](https://github.com/NVlabs/FoundationPose/issues/44#issuecomment-2048141043) and [this](https://github.com/030422Lee/FoundationPose_manual)

## Training Data Download

Our training data include scenes using 3D assets from GSO and Objaverse, rendered with high quality photo-realism and large domain randomization. Each data point includes **RGB, depth, object pose, camera pose, instance segmentation, 2D bounding box**. [[Google Drive]](https://drive.google.com/drive/folders/1s4pB6p4ApfWMiMjmTXOFco8dHbNXikp-?usp=sharing).

<img src="assets/train_data_vis.png" width="80%">

- To parse the camera params including extrinsics and intrinsics

  ```python
  glcam_in_cvcam = np.array([[1,0,0,0],
                          [0,-1,0,0],
                          [0,0,-1,0],
                          [0,0,0,1]]).astype(float)
  W, H = camera_params["renderProductResolution"]
  with open(f'{base_dir}/camera_params/camera_params_000000.json','r') as ff:
    camera_params = json.load(ff)
  world_in_glcam = np.array(camera_params['cameraViewTransform']).reshape(4,4).T
  cam_in_world = np.linalg.inv(world_in_glcam)@glcam_in_cvcam
  world_in_cam = np.linalg.inv(cam_in_world)
  focal_length = camera_params["cameraFocalLength"]
  horiz_aperture = camera_params["cameraAperture"][0]
  vert_aperture = H / W * horiz_aperture
  focal_y = H * focal_length / vert_aperture
  focal_x = W * focal_length / horiz_aperture
  center_y = H * 0.5
  center_x = W * 0.5

  fx, fy, cx, cy = focal_x, focal_y, center_x, center_y
  K = np.eye(3)
  K[0,0] = fx
  K[1,1] = fy
  K[0,2] = cx
  K[1,2] = cy
  ```

## Notes

Due to the legal restrictions of Stable-Diffusion that is trained on LAION dataset, we are not able to release the diffusion-based texture augmented data, nor the pretrained weights using it. We thus release the version without training on diffusion-augmented data. Slight performance degradation is expected.

## Acknowledgement

We would like to thank Jeff Smith for helping with the code release; NVIDIA Isaac Sim and Omniverse team for the support on synthetic data generation; Tianshi Cao for the valuable discussions. Finally, we are also grateful for the positive feebacks and constructive suggestions brought up by reviewers and AC at CVPR.

<img src="assets/cvpr_review.png" width="100%">

## License

The code and data are released under the NVIDIA Source Code License. Copyright © 2024, NVIDIA Corporation. All rights reserved.

## Contact

For questions, please contact [Bowen Wen](https://wenbowen123.github.io/).
