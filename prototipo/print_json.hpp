#pragma once
#include "hailo_objects.hpp"
#include "hailo_common.hpp"
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <unistd.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <signal.h>

#include <time.h>

__BEGIN_DECLS
void my_function(HailoROIPtr roi);
void two_streams(HailoROIPtr roi);
void four_streams(HailoROIPtr roi);
void eight_streams(HailoROIPtr roi);
void sixteen_streams(HailoROIPtr roi);
__END_DECLS