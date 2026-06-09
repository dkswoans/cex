import '../models/machine_model.dart';

extension MachineDisplayNames on MachineModel {
  String get homeMapLabel {
    return switch (machineId) {
      'squat_rack_1' => '스미스1',
      'squat_rack_2' => '스미스2',
      _ => shortName,
    };
  }

  String get detailDisplayName {
    return switch (machineId) {
      'squat_rack_1' => '스미스머신1',
      'squat_rack_2' => '스미스머신2',
      _ => name,
    };
  }
}
