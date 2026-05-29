
class Pet {
  int? id;
  int userId;
  String name;
  String species;
  String breed;
  int age;
  double weight;
  String photo;
  String medicalNotes;

  Pet({
    this.id,
    required this.userId,
    required this.name,
    required this.species,
    this.breed = '',
    this.age = 0,
    this.weight = 0,
    this.photo = '',
    this.medicalNotes = '',
  });

  factory Pet.fromJson(Map<String, dynamic> json) {
    return Pet(
      id: _parseInt(json['id']),
      userId: _parseInt(json['user_id']),
      name: json['name']?.toString() ?? '',
      species: json['species']?.toString() ?? 'other',
      breed: json['breed']?.toString() ?? '',
      age: _parseInt(json['age']),
      weight: _parseDouble(json['weight']),
      photo: json['photo']?.toString() ?? '',
      medicalNotes: json['medical_notes']?.toString() ?? '',
    );
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'name': name,
      'species': species,
      'breed': breed,
      'age': age,
      'weight': weight,
      'photo': photo,
      'medical_notes': medicalNotes,
    };
  }
  
  String get speciesName {
    switch(species) {
      case 'dog': return 'Anjing';
      case 'cat': return 'Kucing';
      case 'rabbit': return 'Kelinci';
      case 'hamster': return 'Hamster';
      case 'bird': return 'Burung';
      default: return species;
    }
  }
}