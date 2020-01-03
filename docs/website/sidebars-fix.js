const fs = require('fs');
const sidebarsJsonFile = `${__dirname}/sidebars.json`;

const sidebars = require(sidebarsJsonFile);

let sidebarsFixed = {'docs-api' : {}};

for (const k in sidebars['docs-api']) {
	if (k == 'UNCATEGORIZED') {
		sidebarsFixed['docs-api']['root'] = sidebars['docs-api'][k];
	} else {
		sidebarsFixed['docs-api'][k.toLowerCase()] = sidebars['docs-api'][k];
	}
}

sidebarsFixed['docs-api'][' '] = ['index'];

const Registry_Owned_Index = sidebarsFixed['docs-api']['root'].indexOf('Registry_Owned');
if (Registry_Owned_Index >= 0) {
	sidebarsFixed['docs-api']['root'].splice(Registry_Owned_Index, 1);
}

let Sacrifice_Index
Sacrifice_Index = sidebarsFixed['docs-api']['base'].indexOf('base_BlockRewardAuRaBase_Sacrifice');
if (Sacrifice_Index >= 0) {
	sidebarsFixed['docs-api']['base'].splice(Sacrifice_Index, 1);
}
Sacrifice_Index = sidebarsFixed['docs-api']['base'].indexOf('base_StakingAuRaCoins_Sacrifice');
if (Sacrifice_Index >= 0) {
	sidebarsFixed['docs-api']['base'].splice(Sacrifice_Index, 1);
}

fs.writeFileSync(sidebarsJsonFile, JSON.stringify(sidebarsFixed, null, '  '));