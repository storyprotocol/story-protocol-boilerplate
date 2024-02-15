-include .env

.PHONY: all test clean

all: clean install build

clean :; yarn cache clean

install :; yarn install

update :; forge update

build :; forge build

test :; forge test
