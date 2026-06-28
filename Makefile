CC      = gcc
CFLAGS  = -std=c99 -Wall -Wextra -Werror -pedantic \
           $(shell pkg-config --cflags libusb-1.0) \
           $(shell pkg-config --cflags cups)
LDFLAGS = $(shell pkg-config --libs libusb-1.0) \
           $(shell pkg-config --libs cups)

SRC_DIR = src
OBJ_DIR = build

SRCS = $(wildcard $(SRC_DIR)/*.c)
OBJS = $(patsubst $(SRC_DIR)/%.c, $(OBJ_DIR)/%.o, $(SRCS))

TARGET = epson-l3110-filter

.PHONY: all clean

all: $(OBJ_DIR) $(TARGET)

$(OBJ_DIR):
	mkdir -p $(OBJ_DIR)

$(TARGET): $(OBJS)
	$(CC) $(OBJS) -o $@ $(LDFLAGS)

$(OBJ_DIR)/%.o: $(SRC_DIR)/%.c
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -rf $(OBJ_DIR) $(TARGET)
