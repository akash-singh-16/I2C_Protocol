# I2C_Protocol
The Inter-Integrated Circuit (I2C) protocol is a widely used, synchronous, serial communication protocol designed for low-speed, short-distance communication between multiple devices. It follows a master-slave architecture and requires only two lines for data exchange:

SDA (Serial Data Line) – Transfers data between master and slave.

SCL (Serial Clock Line) – Synchronizes data transmission.

I2C supports multiple slave devices on the same bus using 7-bit or 10-bit addressing. It features start and stop conditions, acknowledgment (ACK/NACK) signals, and configurable clock speeds (standard, fast, and high-speed modes). Due to its simplicity and ability to support multiple devices on a single bus, I2C is widely used in embedded systems, sensors, and EEPROM communication.

Project Implementation
FSM-Based I2C Master Module: Designed using a finite state machine (FSM) to handle:

Precise Start/Stop Control for proper bus management.

Address Transmission to communicate with specific slave devices.

Data Read/Write Operations ensuring reliable communication.

Acknowledgment (ACK) Handling for error checking.

Clock Division and Signal Control: Implemented to ensure accurate I2C timing, stable data transfer, and error detection mechanisms.

SystemVerilog Testbench for Verification:

Modular, Object-Oriented Approach for scalability.

Generator for randomized test scenarios.

Driver to apply transactions to the I2C bus.

Monitor to capture and analyze data.

Scoreboard for comparing actual results with expected values.

This project demonstrates a structured approach to I2C master design and verification, making it suitable for robust and efficient communication in embedded systems.
