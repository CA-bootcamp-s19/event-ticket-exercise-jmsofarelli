pragma solidity ^0.5.0;

/*
 * The EventTicketsV2 contract keeps track of the details and ticket sales of multiple events.
 */
contract EventTicketsV2 {

    /*
        Define an public owner variable. Set it to the creator of the contract when it is initialized.
    */
    address public owner;
    uint   PRICE_TICKET = 100 wei;
    
    constructor() public {
        owner = msg.sender;
    }

    /*
        Create a variable to keep track of the event ID numbers.
    */
    uint public idGenerator;

    /*
        Define an Event struct, similar to the V1 of this contract.
        The struct has 6 fields: description, website (URL), totalTickets, sales, buyers, and isOpen.
        Choose the appropriate variable type for each field.
        The "buyers" field should keep track of addresses and how many tickets each buyer purchases.
    */
    struct Event {
        string description;
        string website;
        uint totalTickets;
        uint sales;
        mapping(address => uint) buyers;
        bool isOpen;
    }

    /*
        Create a mapping to keep track of the events.
        The mapping key is an integer, the value is an Event struct.
        Call the mapping "events".
    */
    mapping(uint => Event) events;

    event LogEventAdded(string desc, string url, uint ticketsAvailable, uint eventId);
    event LogBuyTickets(address buyer, uint eventId, uint numTickets);
    event LogGetRefund(address accountRefunded, uint eventId, uint numTickets);
    event LogEndSale(address owner, uint balance, uint eventId);

    /*
        Create a modifier that throws an error if the msg.sender is not the owner.
    */
    modifier isOwner() {
        require(msg.sender == owner);
        _;
    }

    /*
        Define a function called addEvent().
        This function takes 3 parameters, an event description, a URL, and a number of tickets.
        Only the contract owner should be able to call this function.
        In the function:
            - Set the description, URL and ticket number in a new event.
            - set the event to open
            - set an event ID
            - increment the ID
            - emit the appropriate event
            - return the event's ID
    */
    function addEvent(string memory _description, string memory _website, uint _totalTickets)
        public
        isOwner
        returns (uint)
    {
        uint eventID = idGenerator;
        events[eventID] = Event({
            description: _description,  
            website: _website, 
            totalTickets: _totalTickets, 
            sales: 0,
            isOpen: true
        });
        idGenerator++;
        emit LogEventAdded(_description, _website, _totalTickets, eventID);
        return eventID;
    }

    /*
        Define a function called readEvent().
        This function takes one parameter, the event ID.
        The function returns information about the event this order:
            1. description
            2. URL
            3. tickets available
            4. sales
            5. isOpen
    */
    function readEvent(uint _eventID)
        public
        view
        returns (string memory, string memory, uint, uint, bool)
    {
        Event memory evt = events[_eventID];
        uint ticketsAvailable = evt.totalTickets - evt.sales;
        return (evt.description, evt.website, ticketsAvailable, evt.sales, evt.isOpen);
    }

    /*
        Define a function called buyTickets().
        This function allows users to buy tickets for a specific event.
        This function takes 2 parameters, an event ID and a number of tickets.
        The function checks:
            - that the event sales are open
            - that the transaction value is sufficient to purchase the number of tickets
            - that there are enough tickets available to complete the purchase
        The function:
            - increments the purchasers ticket count
            - increments the ticket sale count
            - refunds any surplus value sent
            - emits the appropriate event
    */
    function buyTickets(uint _eventID, uint _numTickets)
        public
        payable
    {
        Event storage evt = events[_eventID];
        require(evt.isOpen);
        require(msg.value >= PRICE_TICKET * _numTickets);
        require(evt.totalTickets - evt.sales > _numTickets);
        evt.buyers[msg.sender] += _numTickets;
        evt.sales += _numTickets;
        if (msg.value > PRICE_TICKET * _numTickets) {
            uint refundValue = msg.value - PRICE_TICKET * _numTickets;
            (bool success, bytes memory returnedData) = msg.sender.call.value(refundValue)("");
            if (!success) 
                revert('There was a problem refunding the buyer of the ticket');
        }
        emit LogBuyTickets(msg.sender, _eventID, _numTickets);
    }

    /*
        Define a function called getRefund().
        This function allows users to request a refund for a specific event.
        This function takes one parameter, the event ID.
        TODO:
            - check that a user has purchased tickets for the event
            - remove refunded tickets from the sold count
            - send appropriate value to the refund requester
            - emit the appropriate event
    */
    function getRefund(uint _eventID)
        public
        payable
    {
        Event storage evt = events[_eventID];
        uint numTickets = evt.buyers[msg.sender];
        require(numTickets > 0);
        evt.sales -= evt.buyers[msg.sender];
        uint refundValue = PRICE_TICKET * numTickets;
        (bool success, bytes memory returnedData) = msg.sender.call.value(refundValue)("");
        if (success)
            emit LogGetRefund(msg.sender, _eventID, numTickets);
        else 
            revert();
    }
        

    /*
        Define a function called getBuyerNumberTickets()
        This function takes one parameter, an event ID
        This function returns a uint, the number of tickets that the msg.sender has purchased.
    */
    function getBuyerNumberTickets(uint _eventID)
        public
        view
        returns (uint)
    {
        return events[_eventID].buyers[msg.sender];
    }

    /*
        Define a function called endSale()
        This function takes one parameter, the event ID
        Only the contract owner can call this function
        TODO:
            - close event sales
            - transfer the balance from those event sales to the contract owner
            - emit the appropriate event
    */
    function endSale(uint _eventID)
        public
        isOwner
    {
        Event storage evt = events[_eventID];
        evt.isOpen = false;
        uint evtBalance = PRICE_TICKET * evt.sales;
        (bool success, bytes memory returnedData) = msg.sender.call.value(evtBalance)("");
        if (success)
            emit LogEndSale(msg.sender, evtBalance, _eventID);
        else 
            revert("There was a problem ending the sales for the event");
    }
}
