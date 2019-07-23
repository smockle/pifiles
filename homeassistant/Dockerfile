FROM alpine as open-zwave

RUN apk add --no-cache git
RUN mkdir /open-zwave
RUN git clone https://github.com/OpenZWave/open-zwave /open-zwave

FROM homeassistant/raspberrypi3-homeassistant

COPY --from=open-zwave /open-zwave/config/honeywell/th6320zw2003.xml /usr/local/lib/python3.7/site-packages/python_openzwave/ozw_config/honeywell/th6320zw2003.xml
RUN sed -i.bak '/^\s*<Manufacturer id="0039" name="Honeywell">\s*$/,/^</Manufacturer>\s*$/c\
  <Manufacturer id="0039" name="Honeywell">
    <Product config="honeywell/th8320zw1000.xml" id="0001" name="TH8320ZW1000 Touchscreen Thermostat" type="0011"/>
    <Product config="honeywell/th6320zw2003.xml" id="0008" name="TH6320ZW2003 T6 Pro Series Thermostat" type="0011"/>
    <Product config="honeywell/lynx-touch-l5100.xml" id="0003" name="Lynx Touch L5100 / L7000" type="0001"/>
    <Product config="honeywell/39351-ZW3005.xml" id="3038" name="39351 / ZW3005 In-Wall Smart Dimmer" type="4944"/>
  </Manufacturer>' /usr/local/lib/python3.7/site-packages/python_openzwave/ozw_config/manufacturer_specific.xml
