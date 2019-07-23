FROM alpine as open-zwave

RUN apk add --no-cache git
RUN mkdir /open-zwave
RUN git clone https://github.com/OpenZWave/open-zwave /open-zwave

FROM homeassistant/raspberrypi3-homeassistant

COPY --from=open-zwave /open-zwave/config/honeywell/th6320zw2003.xml /usr/local/lib/python3.7/site-packages/python_openzwave/ozw_config/honeywell/th6320zw2003.xml
COPY --from=open-zwave /open-zwave/config/manufacturer_specific.xml /usr/local/lib/python3.7/site-packages/python_openzwave/ozw_config/manufacturer_specific.xml
