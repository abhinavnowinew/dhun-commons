cmake_minimum_required(VERSION 3.14)
project(DhunCommonsPlugin LANGUAGES CXX)

if(DEFINED ENV{LOGOS_MODULE_BUILDER_ROOT})
    include($ENV{LOGOS_MODULE_BUILDER_ROOT}/cmake/LogosModule.cmake)
else()
    message(FATAL_ERROR "LogosModule.cmake not found. Set LOGOS_MODULE_BUILDER_ROOT.")
endif()

logos_module(
    NAME dhun_commons
    REP_FILE src/dhun_commons.rep
    SOURCES
        src/dhun_commons_backend.h
        src/dhun_commons_backend.cpp
    INCLUDE_DIRS
        src
)
