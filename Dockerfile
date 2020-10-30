# https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html#pre-requisites

FROM nvidia/cuda:10.0-cudnn7-devel

#  Install python 3.8

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates \
curl \
netbase \
wget && rm -rf /var/lib/apt/lists/*

RUN cd /usr/local/bin && ln -s idle3 idle && ln -s pydoc3 pydoc && ln -s python3 python && ln -s python3-config python-config

RUN set -ex; if ! command -v gpg > /dev/null; then apt-get update; apt-get install -y --no-install-recommends gnupg dirmngr; rm -rf /var/lib/apt/lists/*; fi
RUN apt-get update && apt-get install -y --no-install-recommends git \
mercurial \
openssh-client \
subversion \
procps 	&& rm -rf /var/lib/apt/lists/*

RUN set -ex; apt-get update; apt-get install -y --no-install-recommends autoconf \
automake \
bzip2 \
dpkg-dev \
file \
g++ \
gcc \
imagemagick \
libbz2-dev \
libc6-dev \
libcurl4-openssl-dev \
libdb-dev \
libevent-dev \
libffi-dev \
libgdbm-dev \
libglib2.0-dev libgmp-dev libjpeg-dev libkrb5-dev liblzma-dev libmagickcore-dev libmagickwand-dev libmaxminddb-dev \
libncurses5-dev libncursesw5-dev libpng-dev libpq-dev libreadline-dev libsqlite3-dev libssl-dev libtool libwebp-dev \
libxml2-dev libxslt-dev libyaml-dev make patch unzip xz-utils zlib1g-dev \
$( if apt-cache show 'default-libmysqlclient-dev' 2>/dev/null | grep -q '^Version:'; \
then echo 'default-libmysqlclient-dev'; else echo 'libmysqlclient-dev'; fi); rm -rf /var/lib/apt/lists/*

ENV PATH=/usr/local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENV LANG=C.UTF-8

RUN apt-get update && apt-get install -y --no-install-recommends libbluetooth-dev uuid-dev && rm -rf /var/lib/apt/lists/*

ENV PYTHON_VERSION=3.8.6

RUN set -ex && wget -O python.tar.xz "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz" \
&& mkdir -p /usr/src/python \
&& tar -xJC /usr/src/python --strip-components=1 -f python.tar.xz \
&& rm python.tar.xz && cd /usr/src/python && gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
&& ./configure --build="$gnuArch" --enable-loadable-sqlite-extensions --enable-optimizations --enable-option-checking=fatal --enable-shared --with-system-expat --with-system-ffi --without-ensurepip \
&& make -j "$(nproc)" && make install && rm -rf /usr/src/python && find /usr/local -depth \
\( 			\( -type d -a \( -name test -o -name tests -o -name idle_test \) \) 			-o \( -type f -a \( -name '*.pyc' -o -name '*.pyo' -o -name '*.a' \) \) 			-o \( -type f -a -name 'wininst-*.exe' \) 		\) -exec rm -rf '{}' + && ldconfig && python3 --version

RUN cd /usr/local/bin && ln -sf idle3 idle && ln -sf pydoc3 pydoc && ln -sf python3 python && ln -sf python3-config python-config

ENV PYTHON_PIP_VERSION=20.2.4
ENV PYTHON_GET_PIP_URL=https://github.com/pypa/get-pip/raw/8283828b8fd6f1783daf55a765384e6d8d2c5014/get-pip.py
ENV PYTHON_GET_PIP_SHA256=2250ab0a7e70f6fd22b955493f7f5cf1ea53e70b584a84a32573644a045b4bfb

RUN set -ex; wget -O get-pip.py "$PYTHON_GET_PIP_URL"; echo "$PYTHON_GET_PIP_SHA256 *get-pip.py" | sha256sum --check --strict -; python get-pip.py --disable-pip-version-check --no-cache-dir "pip==$PYTHON_PIP_VERSION"; pip --version; rm -f get-pip.py

# Install face recognition dependencies

RUN apt-get update -y; apt-get install -y \
git \
cmake \
libsm6 \
libxext6 \
libxrender-dev

RUN pip install scikit-build

# Install compilers

RUN apt-get install -y software-properties-common
RUN add-apt-repository ppa:ubuntu-toolchain-r/test
RUN apt-get update -y; apt-get install -y gcc-6 g++-6

RUN update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-6 50
RUN update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-6 50

# Install dlib

RUN git clone -b 'v19.21' --single-branch https://github.com/davisking/dlib.git
RUN mkdir -p /dlib/build

RUN cmake -H/dlib -B/dlib/build -DDLIB_USE_CUDA=1 -DUSE_AVX_INSTRUCTIONS=1
RUN cmake --build /dlib/build

RUN cd /dlib; python /dlib/setup.py install


# Install OpenCV-GPU

# https://en.wikipedia.org/wiki/CUDA#GPUs_supported
RUN apt-get update && apt-get install -y build-essential unzip pkg-config \
libjpeg-dev libpng-dev libtiff-dev \
libavcodec-dev libavformat-dev libswscale-dev \
libv4l-dev libxvidcore-dev libx264-dev \
libgtk-3-dev libatlas-base-dev gfortran \
libgl1-mesa-glx cuda-cudart-10-1

RUN wget -O opencv.zip https://github.com/opencv/opencv/archive/4.5.0.zip && unzip opencv.zip && mv opencv-4.5.0 opencv
RUN wget -O opencv_contrib.zip https://github.com/opencv/opencv_contrib/archive/4.5.0.zip && unzip opencv_contrib.zip && mv opencv_contrib-4.5.0 opencv_contrib

RUN cd /opencv; mkdir build && cd build && cmake -D CMAKE_BUILD_TYPE=RELEASE \
	-D CMAKE_INSTALL_PREFIX=/usr/local \
	-D WITH_CUDA=ON \
	-D WITH_CUDNN=ON \
	-D OPENCV_DNN_CUDA=ON \
	-D ENABLE_FAST_MATH=1 \
	-D CUDA_FAST_MATH=1 \
	-D CUDA_GENERATION=Auto \
	-D WITH_CUBLAS=1 \
	-D OPENCV_EXTRA_MODULES_PATH=/opencv_contrib/modules \
	-D HAVE_opencv_python3=ON .. \
	&& make -j "$(nproc)" && make install && ldconfig

# pip instlal
RUN pip install numpy==1.18.5
