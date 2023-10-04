// SPDX-License-Identifier: MIT
pragma solidity >0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

//Errors
error No_Simple_Card_NFTs_To_Transfer();


contract SimpleCardNFTFactory is ERC721 {
    //State Variables
    uint public tokenId; //처음 선언할 때 tokenId=0

    struct SimpleCardInfo { //내 명함에 들어가는 기본적인 정보들로 구조체(여러 개의 변수를 하나의 단위로 묶어서 관리할 수 있게 해주는 데이터 타입)를 만듦
        //essential
        string name;
        string email;
        address issuer; //발급한 사람. 즉 명함 정보의 주인
        
        //optional
        string company;
        string portfolio;
    }

    mapping(address  => SimpleCardInfo ) private _infos; //issuer가 발급한 명함 정보
    mapping(address => uint[]) private _tokenIdsMadeByIssuer;  //issuer가 발급한 명함의 tokenId들
    mapping(address => mapping(uint=> bool)) private _isTokenStillOwnedByIssuer; //issuer가 발급한 tokenId들이 현재 issuer에게 있는지. 있으면 true, 없으면 false
    mapping(uint => address) private _issuerOfToken; //tokenId의 issuer
    mapping(address => uint) private _amountOfTokenOwnedByIssuer; //issuer가 현재 가지고 있는 자신의 명함 개수(발급한 양 - 남들에게 transfer한 양) //ERC721의 _balances는 자신의 명함 개수 뿐만 아니라 자신이 받은 명함 개수까지 value값으로 가진다는 점에서 이 mapping과 차이점을 가짐. 
    mapping(uint => address) private _ownerOfToken; // Token의 owner를 저장

    //Events
    event SimpleCardInfoRegistered(
        address indexed issuer,
        string name,
        string email,
        string company,
        string portfolio
    );

    event SimpleCardNFTMinted(
        uint indexed tokenId,
        address issuer,
        uint amountOfTokenOwnedByIssuer
    );

    event SimpleCardNFTTransfered(
        address indexed to,
        address from,
        uint tokenId,
        uint amountOfTokenOwnedByIssuer
    );


    //Modifiers
    modifier isSimpleCardInfoRegistered(){
        SimpleCardInfo memory mySimpleCardInfo = _infos[msg.sender];
        require(
            keccak256(abi.encodePacked(mySimpleCardInfo.name)) != keccak256(abi.encodePacked("")),
            "Register your Simple Card info First"
        );
        _;
    }

    modifier isTokenOwner(uint tokenId) {
    require(_ownerOfToken[tokenId] == msg.sender, "Purchase for details");
    _;
    }


    //Constructors
    constructor() ERC721("SimpleCardNFT", "SCard") {}


    //Functions
    function registerSimpleCardInfo (//자신의 명함 NFT 정보 작성
        string memory _name, 
        string memory _email,
        string memory _company,
        string memory _portfolio
    )public{
        SimpleCardInfo memory simpleCardInfo = SimpleCardInfo({
            name:_name,
            email:_email,
            issuer: msg.sender,
            company:_company,
            portfolio:_portfolio
        });
               
        _infos[msg.sender] = simpleCardInfo;

        emit SimpleCardInfoRegistered(msg.sender, _name, _email, _company, _portfolio);
    } 

    function mintSimpleCardNFT () public payable isSimpleCardInfoRegistered{ //자신의 명함 NFT 한 개 발급      
        tokenId++;
        
        _mint(msg.sender, tokenId);

        _ownerOfToken[tokenId] = msg.sender;

        //tokenIds 관련 매핑 업데이트
        uint[] storage tokenIdsMadeByIssuer = _tokenIdsMadeByIssuer[msg.sender];
        tokenIdsMadeByIssuer.push(tokenId);
        _isTokenStillOwnedByIssuer[msg.sender][tokenId] = true;
        _issuerOfToken[tokenId] = msg.sender;      
        _amountOfTokenOwnedByIssuer[msg.sender]++;

        emit SimpleCardNFTMinted(tokenId,msg.sender, _amountOfTokenOwnedByIssuer[msg.sender]);
    }

    function transferSimpleCardNFT (address to) public isSimpleCardInfoRegistered{
        require(_amountOfTokenOwnedByIssuer[msg.sender]!=0,"Mint your Simple Card NFT first");

        uint _tokenIdToTransfer;
        uint[] memory tokenIdsMadeByIssuer =_tokenIdsMadeByIssuer[msg.sender];
        for (uint i=0;i<tokenIdsMadeByIssuer.length;i++) {
            uint _tokenIdMadeByIssuer = tokenIdsMadeByIssuer[i];
            if (_isTokenStillOwnedByIssuer[msg.sender][_tokenIdMadeByIssuer]==true) {
                _tokenIdToTransfer = _tokenIdMadeByIssuer;
                break;
            }
            if ((i==tokenIdsMadeByIssuer.length-1)&&(_isTokenStillOwnedByIssuer[msg.sender][_tokenIdMadeByIssuer]==false)){
                revert No_Simple_Card_NFTs_To_Transfer();
            }
        }

        safeTransferFrom(msg.sender, to, _tokenIdToTransfer);

        //Token의 소유자 업데이트
        _ownerOfToken[_tokenIdToTransfer] = to;

        //tokenIds 관련 매핑 업데이트
        _isTokenStillOwnedByIssuer[msg.sender][_tokenIdToTransfer]= false;
        _amountOfTokenOwnedByIssuer[msg.sender] --;

        emit SimpleCardNFTTransfered(to, msg.sender, _tokenIdToTransfer, _amountOfTokenOwnedByIssuer[msg.sender]);
    }


    //getter 함수
    function getSimpleCardInfo(uint tokenId) external view isTokenOwner(tokenId) returns (SimpleCardInfo memory) {
        return _infos[msg.sender];
    }


    function getAmountOfTokenOwnedByIssuer(address issuer) external view returns (uint){
        return _amountOfTokenOwnedByIssuer[issuer];
    }

}
