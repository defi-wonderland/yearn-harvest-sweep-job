pragma solidity >=0.8.4 <0.9.0;

/*///////////////////////////////////////////////////////////////
                      Test fixture related                   
//////////////////////////////////////////////////////////////*/

uint256 constant HARVEST_COOLDOWN = 21_600;
uint256 constant TEND_COOLDOWN = 300;
uint256 constant ONE = 1 ether;
uint256 constant MIN_BOND = 50 ether;
uint256 constant MAX_BOND = 200 ether;
uint256 constant EARNED = 0;
uint256 constant AGE = 0;
bool constant ONLY_EOA = true;
address constant BOND = KP3R_V1_ADDRESS;

/*///////////////////////////////////////////////////////////////
                          V2 Keeper related                  
//////////////////////////////////////////////////////////////*/

address constant V2_KEEPER = address(0x736D7e3c5a6CB2CE3B764300140ABF476F6CFCCF);
address constant PUBLIC_KEEPER = address(0x0D26E894C2371AB6D20d99A65E991775e3b5CAd7);
address constant V2_KEEPER_GOVERNOR = address(0x2C01B4AD51a67E2d8F02208F54dF9aC4c0B778B6);
address constant MECHANICS_REGISTRY = address(0xE8d5A85758FE98F7Dce251CAd552691D49b499Bb);
address constant VAULT_REGISTRY = address(0xaF1f5e1c19cB68B30aAD73846eFfDf78a5863319);
address constant STEALTH_RELAYER = address(0x0a61c2146A7800bdC278833F21EBf56Cd660EE2a);
address constant STEALTH_VAULT = address(0xde2fe402A285363283853bEC903d134426DB3Ff7);
address constant HARVEST_V2_KEEP3R_STEALTH_JOB = address(0x2150b45626199CFa5089368BDcA30cd0bfB152D6);
address constant STR_CONVEX_ST_ETH = address(0x6C0496fC55Eb4089f1Cf91A4344a2D56fAcE51e3);

/*///////////////////////////////////////////////////////////////
                         Keep3r V2 related                  
//////////////////////////////////////////////////////////////*/

address constant KEEP3R_V2 = address(0xeb02addCfD8B773A5FFA6B9d1FE99c566f8c44CC);
address constant KEEP3R_V2_HELPER = address(0xeDDe080E28Eb53532bD1804de51BD9Cd5cADF0d4);
address constant KEEPER_ADDRESS = address(0x99B2C5D50086b02f83E791633C5660fbb8344653);
address constant KP3R_WHALE = address(0xa89a1278Ac85367F38BDF6746658CE2B9875526E);
address constant KP3R_WETH_V3_POOL_ADDRESS = address(0x11B7a6bc0259ed6Cf9DB8F499988F9eCc7167bf5);
address constant KP3R_V1_ADDRESS = address(0x1cEB5cB57C4D4E2b2433641b95Dd330A33185A44);
address constant KP3R_V1_PROXY_ADDRESS = address(0x976b01c02c636Dd5901444B941442FD70b86dcd5);
address constant KP3R_V1_PROXY_GOVERNANCE_ADDRESS = address(0x0D5Dc686d0a2ABBfDaFDFb4D0533E886517d4E83);
address constant KP3R_V1_GOVERNANCE_ADDRESS = address(0xFC48aC750959d5d5aE9A4bb38f548A7CA8763F8d);
address constant KP3R_LP_TOKEN = address(0x3f6740b5898c5D3650ec6eAce9a649Ac791e44D7);

/*///////////////////////////////////////////////////////////////
                                Misc                       
//////////////////////////////////////////////////////////////*/

address constant ZERO_ADDRESS = address(0x0000000000000000000000000000000000000000);
address constant ETH_ADDRESS = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
address constant WETH_ADDRESS = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
