import 'package:latlong2/latlong.dart';

class IndianLocations {
  static final Map<String, Map<String, LatLng>> statesAndCities = {
    'Andhra Pradesh': {
      'Visakhapatnam': LatLng(17.6869, 83.2185),
      'Vijayawada': LatLng(16.5062, 80.6480),
      'Guntur': LatLng(16.3067, 80.4365),
      'Nellore': LatLng(14.4426, 79.9865),
      'Kurnool': LatLng(15.8281, 78.0373),
      'Tirupati': LatLng(13.6288, 79.4192),
      'Rajahmundry': LatLng(17.0005, 81.8040),
      'Kakinada': LatLng(16.9891, 82.2475),
    },
    'Arunachal Pradesh': {
      'Itanagar': LatLng(27.0844, 93.6053),
      'Naharlagun': LatLng(27.1000, 93.7000),
      'Pasighat': LatLng(28.0660, 95.3260),
      'Tawang': LatLng(27.5860, 91.8570),
    },
    'Assam': {
      'Guwahati': LatLng(26.1445, 91.7362),
      'Silchar': LatLng(24.8333, 92.7789),
      'Dibrugarh': LatLng(27.4728, 94.9120),
      'Jorhat': LatLng(26.7509, 94.2037),
      'Nagaon': LatLng(26.3484, 92.6856),
      'Tinsukia': LatLng(27.4900, 95.3600),
    },
    'Bihar': {
      'Patna': LatLng(25.5941, 85.1376),
      'Gaya': LatLng(24.7955, 85.0002),
      'Bhagalpur': LatLng(25.2425, 86.9842),
      'Muzaffarpur': LatLng(26.1225, 85.3906),
      'Darbhanga': LatLng(26.1542, 85.8918),
      'Purnia': LatLng(25.7771, 87.4753),
    },
    'Chhattisgarh': {
      'Raipur': LatLng(21.2514, 81.6296),
      'Bhilai': LatLng(21.2167, 81.3833),
      'Bilaspur': LatLng(22.0797, 82.1409),
      'Korba': LatLng(22.3595, 82.7501),
      'Durg': LatLng(21.1900, 81.2800),
    },
    'Goa': {
      'Panaji': LatLng(15.4909, 73.8278),
      'Margao': LatLng(15.2700, 73.9500),
      'Vasco da Gama': LatLng(15.3983, 73.8115),
      'Mapusa': LatLng(15.5900, 73.8100),
    },
    'Gujarat': {
      'Ahmedabad': LatLng(23.0225, 72.5714),
      'Surat': LatLng(21.1702, 72.8311),
      'Vadodara': LatLng(22.3072, 73.1812),
      'Rajkot': LatLng(22.3039, 70.8022),
      'Bhavnagar': LatLng(21.7645, 72.1519),
      'Jamnagar': LatLng(22.4707, 70.0577),
      'Gandhinagar': LatLng(23.2156, 72.6369),
      'Anand': LatLng(22.5645, 72.9289),
    },
    'Haryana': {
      'Faridabad': LatLng(28.4089, 77.3178),
      'Gurgaon': LatLng(28.4595, 77.0266),
      'Panipat': LatLng(29.3909, 76.9635),
      'Ambala': LatLng(30.3782, 76.7767),
      'Karnal': LatLng(29.6857, 76.9905),
      'Rohtak': LatLng(28.8955, 76.6066),
    },
    'Himachal Pradesh': {
      'Shimla': LatLng(31.1048, 77.1734),
      'Manali': LatLng(32.2396, 77.1887),
      'Dharamshala': LatLng(32.2190, 76.3234),
      'Kullu': LatLng(31.9578, 77.1093),
      'Solan': LatLng(30.9045, 77.0967),
    },
    'Jharkhand': {
      'Ranchi': LatLng(23.3441, 85.3096),
      'Jamshedpur': LatLng(22.8046, 86.2029),
      'Dhanbad': LatLng(23.7957, 86.4304),
      'Bokaro': LatLng(23.6693, 86.1511),
      'Hazaribagh': LatLng(23.9929, 85.3615),
    },
    'Karnataka': {
      'Bangalore': LatLng(12.9716, 77.5946),
      'Mysore': LatLng(12.2958, 76.6394),
      'Mangalore': LatLng(12.9141, 74.8560),
      'Hubli': LatLng(15.3647, 75.1240),
      'Belgaum': LatLng(15.8497, 74.4977),
      'Gulbarga': LatLng(17.3297, 76.8343),
      'Davangere': LatLng(14.4644, 75.9218),
      'Bellary': LatLng(15.1394, 76.9214),
    },
    'Kerala': {
      'Thiruvananthapuram': LatLng(8.5241, 76.9366),
      'Kochi': LatLng(9.9312, 76.2673),
      'Kozhikode': LatLng(11.2588, 75.7804),
      'Thrissur': LatLng(10.5276, 76.2144),
      'Kollam': LatLng(8.8932, 76.6141),
      'Kannur': LatLng(11.8745, 75.3704),
      'Alappuzha': LatLng(9.4981, 76.3388),
    },
    'Madhya Pradesh': {
      'Indore': LatLng(22.7196, 75.8577),
      'Bhopal': LatLng(23.2599, 77.4126),
      'Jabalpur': LatLng(23.1815, 79.9864),
      'Gwalior': LatLng(26.2183, 78.1828),
      'Ujjain': LatLng(23.1765, 75.7885),
      'Sagar': LatLng(23.8388, 78.7378),
    },
    'Maharashtra': {
      'Mumbai': LatLng(19.0760, 72.8777),
      'Pune': LatLng(18.5204, 73.8567),
      'Nagpur': LatLng(21.1458, 79.0882),
      'Nashik': LatLng(19.9975, 73.7898),
      'Aurangabad': LatLng(19.8762, 75.3433),
      'Solapur': LatLng(17.6599, 75.9064),
      'Thane': LatLng(19.2183, 72.9781),
      'Kolhapur': LatLng(16.7050, 74.2433),
    },
    'Manipur': {
      'Imphal': LatLng(24.8170, 93.9368),
      'Thoubal': LatLng(24.6333, 93.9833),
      'Bishnupur': LatLng(24.6167, 93.7667),
    },
    'Meghalaya': {
      'Shillong': LatLng(25.5788, 91.8933),
      'Tura': LatLng(25.5138, 90.2036),
      'Jowai': LatLng(25.4500, 92.2000),
    },
    'Mizoram': {
      'Aizawl': LatLng(23.7271, 92.7176),
      'Lunglei': LatLng(22.8833, 92.7333),
      'Champhai': LatLng(23.4833, 93.3167),
    },
    'Nagaland': {
      'Kohima': LatLng(25.6747, 94.1086),
      'Dimapur': LatLng(25.9067, 93.7267),
      'Mokokchung': LatLng(26.3167, 94.5167),
    },
    'Odisha': {
      'Bhubaneswar': LatLng(20.2961, 85.8245),
      'Cuttack': LatLng(20.4625, 85.8828),
      'Rourkela': LatLng(22.2604, 84.8536),
      'Puri': LatLng(19.8135, 85.8312),
      'Berhampur': LatLng(19.3150, 84.7941),
    },
    'Punjab': {
      'Ludhiana': LatLng(30.9010, 75.8573),
      'Amritsar': LatLng(31.6340, 74.8723),
      'Jalandhar': LatLng(31.3260, 75.5762),
      'Patiala': LatLng(30.3398, 76.3869),
      'Bathinda': LatLng(30.2110, 74.9455),
      'Mohali': LatLng(30.7046, 76.7179),
    },
    'Rajasthan': {
      'Jaipur': LatLng(26.9124, 75.7873),
      'Jodhpur': LatLng(26.2389, 73.0243),
      'Udaipur': LatLng(24.5854, 73.7125),
      'Kota': LatLng(25.2138, 75.8648),
      'Ajmer': LatLng(26.4499, 74.6399),
      'Bikaner': LatLng(28.0229, 73.3119),
    },
    'Sikkim': {
      'Gangtok': LatLng(27.3389, 88.6065),
      'Namchi': LatLng(27.1667, 88.3667),
      'Gyalshing': LatLng(27.2833, 88.0500),
    },
    'Tamil Nadu': {
      'Chennai': LatLng(13.0827, 80.2707),
      'Coimbatore': LatLng(11.0168, 76.9558),
      'Madurai': LatLng(9.9252, 78.1198),
      'Tiruchirappalli': LatLng(10.7905, 78.7047),
      'Salem': LatLng(11.6643, 78.1460),
      'Tirunelveli': LatLng(8.7139, 77.7567),
      'Erode': LatLng(11.3410, 77.7172),
      'Vellore': LatLng(12.9165, 79.1325),
      'Thoothukudi': LatLng(8.7642, 78.1348),
      'Thanjavur': LatLng(10.7870, 79.1378),
    },
    'Telangana': {
      'Hyderabad': LatLng(17.3850, 78.4867),
      'Warangal': LatLng(17.9784, 79.6000),
      'Nizamabad': LatLng(18.6725, 78.0941),
      'Khammam': LatLng(17.2473, 80.1514),
      'Karimnagar': LatLng(18.4386, 79.1288),
    },
    'Tripura': {
      'Agartala': LatLng(23.8315, 91.2868),
      'Udaipur': LatLng(23.5333, 91.4833),
      'Dharmanagar': LatLng(24.3667, 92.1667),
    },
    'Uttar Pradesh': {
      'Lucknow': LatLng(26.8467, 80.9462),
      'Kanpur': LatLng(26.4499, 80.3319),
      'Ghaziabad': LatLng(28.6692, 77.4538),
      'Agra': LatLng(27.1767, 78.0081),
      'Varanasi': LatLng(25.3176, 82.9739),
      'Meerut': LatLng(28.9845, 77.7064),
      'Allahabad': LatLng(25.4358, 81.8463),
      'Bareilly': LatLng(28.3670, 79.4304),
    },
    'Uttarakhand': {
      'Dehradun': LatLng(30.3165, 78.0322),
      'Haridwar': LatLng(29.9457, 78.1642),
      'Roorkee': LatLng(29.8543, 77.8880),
      'Haldwani': LatLng(29.2183, 79.5130),
      'Rudrapur': LatLng(28.9845, 79.4004),
    },
    'West Bengal': {
      'Kolkata': LatLng(22.5726, 88.3639),
      'Howrah': LatLng(22.5958, 88.2636),
      'Durgapur': LatLng(23.5204, 87.3119),
      'Asansol': LatLng(23.6739, 86.9524),
      'Siliguri': LatLng(26.7271, 88.3953),
      'Darjeeling': LatLng(27.0410, 88.2663),
    },
    'Delhi': {
      'New Delhi': LatLng(28.6139, 77.2090),
      'Delhi': LatLng(28.7041, 77.1025),
      'Dwarka': LatLng(28.5921, 77.0460),
      'Rohini': LatLng(28.7495, 77.0736),
    },
    'Puducherry': {
      'Puducherry': LatLng(11.9416, 79.8083),
      'Karaikal': LatLng(10.9254, 79.8380),
      'Mahe': LatLng(11.7014, 75.5360),
    },
    'Jammu and Kashmir': {
      'Srinagar': LatLng(34.0837, 74.7973),
      'Jammu': LatLng(32.7266, 74.8570),
      'Anantnag': LatLng(33.7311, 75.1486),
      'Baramulla': LatLng(34.2095, 74.3434),
    },
    'Ladakh': {
      'Leh': LatLng(34.1526, 77.5771),
      'Kargil': LatLng(34.5539, 76.1313),
    },
  };

  static List<String> getStates() {
    return statesAndCities.keys.toList()..sort();
  }

  static List<String> getCitiesForState(String state) {
    return statesAndCities[state]?.keys.toList() ?? [];
  }

  static LatLng? getCoordinates(String state, String city) {
    return statesAndCities[state]?[city];
  }
}
