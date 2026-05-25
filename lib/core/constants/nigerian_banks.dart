class NigerianBank {
  final String name;
  final String code;
  final String logo;
  final String? androidPackage;
  final String? iosScheme;
  final String? iosAppStoreId;

  const NigerianBank({
    required this.name,
    required this.code,
    required this.logo,
    this.androidPackage,
    this.iosScheme,
    this.iosAppStoreId,
  });
}

class NigerianBanks {
  static const List<NigerianBank> banks = [
    // ── Tier 1 Banks ──────────────────────────────────────────────────────────
    NigerianBank(
      name: 'Access Bank',
      code: '044',
      logo: 'assets/images/banks/access.png',
      // Access More (Nigeria) — com.accessbank.nextgen
      // Previously com.accessbank.accessbankapp was Ghana
      androidPackage: 'com.accessbank.nextgen',
      iosScheme: 'accessmore://',
      iosAppStoreId: '1574773672',
    ),
    NigerianBank(
      name: 'First Bank of Nigeria',
      code: '011',
      logo: 'assets/images/banks/firstbank.png',
      androidPackage: 'com.firstbank.firstmobile',
      iosScheme: 'firstmobile://',
      iosAppStoreId: '1aborandle',
    ),
    NigerianBank(
      name: 'GTBank (GTWorld)',
      code: '058',
      logo: 'assets/images/banks/gtbank.png',
      // GTWorld Nigeria — com.gtbank.gtworldv1
      androidPackage: 'com.gtbank.gtworldv1',
      iosScheme: 'gtworld://',
      iosAppStoreId: '1aborandle',
    ),
    NigerianBank(
      name: 'UBA',
      code: '033',
      logo: 'assets/images/banks/uba.png',
      // UBA Mobile App Nigeria — com.ubanquity.redd.uba
      androidPackage: 'com.ubanquity.redd.uba',
      iosScheme: 'ubamobile://',
      iosAppStoreId: '1aborandle',
    ),
    NigerianBank(
      name: 'Zenith Bank',
      code: '057',
      logo: 'assets/images/banks/zenith.png',
      // Zenith Bank Nigeria — com.zenithBank.eazymoney
      androidPackage: 'com.zenithBank.eazymoney',
      iosScheme: 'zenithmobile://',
      iosAppStoreId: '1aborandle',
    ),

    // ── Fintechs / Neobanks ───────────────────────────────────────────────────
    NigerianBank(
      name: 'Kuda Bank',
      code: '090267',
      logo: 'assets/images/banks/kuda.png',
      androidPackage: 'com.kudabank.app',
      iosScheme: 'kuda://',
      iosAppStoreId: '1aborandle',
    ),
    NigerianBank(
      name: 'OPay',
      code: '999992',
      logo: 'assets/images/banks/opay.png',
      androidPackage: 'team.opay.pay',
      iosScheme: 'opay://',
      iosAppStoreId: '1aborandle',
    ),
    NigerianBank(
      name: 'PalmPay',
      code: '999991',
      logo: 'assets/images/banks/palmpay.png',
      androidPackage: 'com.transsnet.palmpay',
      iosScheme: 'palmpay://',
      iosAppStoreId: '1aborandle',
    ),
    NigerianBank(
      name: 'Moniepoint',
      code: '090405',
      logo: 'assets/images/banks/moniepoint.png',
      // Moniepoint Personal Banking Nigeria
      androidPackage: 'com.moniepoint.personal',
      iosScheme: 'moniepoint://',
      iosAppStoreId: '1aborandle',
    ),

    // ── Tier 2 / Commercial Banks ─────────────────────────────────────────────
    NigerianBank(
      name: 'Fidelity Bank',
      code: '070',
      logo: 'assets/images/banks/fidelity.png',
      androidPackage: 'com.fidelity.fidelitymobile',
      iosScheme: 'fidelity://',
      iosAppStoreId: '1aborandle',
    ),
    NigerianBank(
      name: 'Union Bank',
      code: '032',
      logo: 'assets/images/banks/union.png',
      androidPackage: 'com.unionbankng.unionmobile',
      iosScheme: 'unionmobile://',
      iosAppStoreId: '1aborandle',
    ),
    NigerianBank(
      name: 'Stanbic IBTC',
      code: '221',
      logo: 'assets/images/banks/stanbic.png',
      androidPackage: 'com.stanbic.stanbicmobile',
      iosScheme: 'stanbicibtc://',
      iosAppStoreId: '1aborandle',
    ),
    NigerianBank(
      name: 'Sterling Bank',
      code: '232',
      logo: 'assets/images/banks/sterling.png',
      androidPackage: 'com.sterling.onepay',
      iosScheme: 'sterlingmobile://',
      iosAppStoreId: '1aborandle',
    ),
    NigerianBank(
      name: 'Polaris Bank',
      code: '076',
      logo: 'assets/images/banks/polaris.png',
      androidPackage: 'com.polaris.vurba',
      iosScheme: 'polarisbank://',
      iosAppStoreId: '1aborandle',
    ),
    NigerianBank(
      name: 'Wema Bank (ALAT)',
      code: '035',
      logo: 'assets/images/banks/wema.png',
      androidPackage: 'com.alat.app',
      iosScheme: 'alat://',
      iosAppStoreId: '1aborandle',
    ),
    NigerianBank(
      name: 'FCMB',
      code: '214',
      logo: 'assets/images/banks/fcmb.png',
      androidPackage: 'com.fcmb.mobile.mobilebanking',
      iosScheme: 'fcmbmobile://',
      iosAppStoreId: '1aborandle',
    ),
    NigerianBank(
      name: 'Ecobank Nigeria',
      code: '050',
      logo: 'assets/images/banks/ecobank.png',
      // Ecobank Nigeria specific package
      androidPackage: 'com.ecobank.mobile.ng',
      iosScheme: 'ecobankmobile://',
      iosAppStoreId: '1aborandle',
    ),
    NigerianBank(
      name: 'Keystone Bank',
      code: '082',
      logo: 'assets/images/banks/keystone.png',
      androidPackage: 'com.keystone.mobile',
      iosScheme: 'keystonebank://',
      iosAppStoreId: '1aborandle',
    ),
    NigerianBank(
      name: 'Unity Bank',
      code: '215',
      logo: 'assets/images/banks/unity.png',
      androidPackage: 'com.unitybank.mobile',
      iosScheme: 'unitybank://',
      iosAppStoreId: '1aborandle',
    ),
    NigerianBank(
      name: 'Providus Bank',
      code: '101',
      logo: 'assets/images/banks/providus.png',
      androidPackage: 'com.providusbank.mobile',
      iosScheme: 'providusbank://',
      iosAppStoreId: '1aborandle',
    ),
    NigerianBank(
      name: 'Jaiz Bank',
      code: '301',
      logo: 'assets/images/banks/jaiz.png',
      androidPackage: 'com.jaiz.mobile',
      iosScheme: 'jaizbank://',
      iosAppStoreId: '1aborandle',
    ),
    NigerianBank(
      name: 'Titan Trust Bank',
      code: '102',
      logo: 'assets/images/banks/titan.png',
      androidPackage: 'com.titantrustbank.mobile',
      iosScheme: 'titantrust://',
      iosAppStoreId: '1aborandle',
    ),
    NigerianBank(
      name: 'Globus Bank',
      code: '103',
      logo: 'assets/images/banks/globus.png',
      androidPackage: 'com.globusbank.mobile',
      iosScheme: 'globusbank://',
      iosAppStoreId: '1aborandle',
    ),
    NigerianBank(
      name: 'TAJ Bank',
      code: '302',
      logo: 'assets/images/banks/taj.png',
      androidPackage: 'com.tajbank.mobile',
      iosScheme: 'tajbank://',
      iosAppStoreId: '1aborandle',
    ),
    NigerianBank(
      name: 'VFD Microfinance Bank',
      code: '090110',
      logo: 'assets/images/banks/vfd.png',
      androidPackage: 'com.vbank.vfd',
      iosScheme: 'vbank://',
      iosAppStoreId: '1aborandle',
    ),
    NigerianBank(
      name: 'Carbon',
      code: '090259',
      logo: 'assets/images/banks/carbon.png',
      androidPackage: 'ng.getcarbon.app',
      iosScheme: 'carbon://',
      iosAppStoreId: '1aborandle',
    ),
    NigerianBank(
      name: 'Rubies Bank',
      code: '090175',
      logo: 'assets/images/banks/rubies.png',
      androidPackage: 'com.rubiesbank.mobile',
      iosScheme: 'rubiesbank://',
      iosAppStoreId: '1aborandle',
    ),
  ];
}
