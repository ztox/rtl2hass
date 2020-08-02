ARG BUILD_FROM
FROM ${BUILD_FROM} AS intermediate

ARG BUILD_ARCH

ENV LANG C.UTF-8
WORKDIR /usr/share/rtl_433 


#
# First install software packages needed to compile RTL-SDR and rtl_433
#

RUN \
    apk add --no-cache --virtual \
    	build_deps \
    	build-base \
	cmake \
	git \	
  	libusb-dev


## Pull in rtl-sdr
RUN \
    mkdir /tmp/src \
    && cd /tmp/src \
    && git clone git://git.osmocom.org/rtl-sdr.git \
    && mkdir /tmp/src/rtl-sdr/build \
    && cd /tmp/src/rtl-sdr/build \
    && cmake ../ -DINSTALL_UDEV_RULES=ON -DDETACH_KERNEL_DRIVER=ON -DCMAKE_INSTALL_PREFIX:PATH=/usr/local \
    && make \
    && make install \
    && chmod +s /usr/local/bin/rtl_* 


#
# Pull RTL_433 source code from GIT, compile it and install it
#

RUN \
  git clone https://github.com/merbanan/rtl_433.git . \
  && mkdir build \
  && cd build \
  && cmake ../ \
  && make \
  && make install

## Multi-stage Build
FROM ${BUILD_FROM} AS final

RUN \
    apk add --nocache --virtual \
    	libtool \
	libusb-dev \
	mosquitto-clients \
	jq\
	librtlsdr-dev \
	rtl-sdr

#
# Define environment variables
# 
# Use this variable when creating a container to specify the MQTT broker host.
ENV MQTT_HOST ""
ENV MQTT_PORT 1883
ENV MQTT_USERNAME ""
ENV MQTT_PASSWORD ""
ENV MQTT_TOPIC rtl_433
ENV DISCOVERY_PREFIX homeassistant
ENV DISCOVERY_INTERVAL 600


# RUN \
#     apt-get update

# RUN \
#     apt-get install --no-install-recommends -y \
#        libtool \
#        libusb-dev \
#        librtlsdr-dev \
#        rtl-sdr 


COPY --from=intermediate /usr/local/include/rtl_433.h /usr/local/include/rtl_433.h
COPY --from=intermediate /usr/local/include/rtl_433_devices.h /usr/local/include/rtl_433_devices.h
COPY --from=intermediate /usr/local/bin/rtl_433 /usr/local/bin/rtl_433
COPY --from=intermediate /usr/local/etc/rtl_433 /usr/local/etc/rtl_433

#
# Install Paho-MQTT client
#
RUN \
    pip3 install --no-cache-dir  -U setuptools wheel

RUN \
    pip3 install --no-cache-dir --prefer-binary \
    --find-links "https://wheels.home-assistant.io/alpine-3.11/${BUILD_ARCH}/" \
    paho-mqtt

#
# Blacklist kernel modules for RTL devices
#
COPY rtl.blacklist.conf /etc/modprobe.d/rtl.blacklist.conf

#
# Copy scripts, make executable
#
COPY entry.sh rtl_433_mqtt_hass.py /scripts/
RUN chmod +x /scripts/entry.sh

#
# Execute entry script
#
ENTRYPOINT [ "/scripts/entry.sh" ]
