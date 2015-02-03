function stop_status = picoDisconnect(picoDevice)

stop_status = invoke(picoDevice, 'ps3000aStop');
disconnect(picoDevice)
clear picoDevice