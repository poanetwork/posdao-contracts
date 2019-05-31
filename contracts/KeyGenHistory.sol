pragma solidity 0.5.9;


contract KeyGenHistory {

    event PartWritten(address indexed sender, bytes part);
    event AckWritten(address indexed sender, bytes ack);

    function writePart(bytes memory _part) public {
        emit PartWritten(msg.sender, _part);
    }

    function writeAck(bytes memory _ack) public {
        emit AckWritten(msg.sender, _ack);
    }

}
