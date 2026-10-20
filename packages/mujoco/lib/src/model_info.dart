/// The four joint types defined by MuJoCo.
enum MjJointType { free, ball, slide, hinge }

/// Sensor meanings independent of the implementation's enum numbering.
enum MjSensorKind { accelerometer, gyro, frameQuaternion, other }

/// A snapshot of joint addresses in the compiled model.
class const MjJointInfo({
  required final int id,
  required final String name,
  required final MjJointType type,
  required final int qposAddress,
  required final int dofAddress,
});

/// A snapshot of actuator transmission and control metadata.
class const MjActuatorInfo({
  required final int id,
  required final String name,
  required final MjJointInfo? joint,
  required final bool isUnitTorqueMotor,
  required final ({double lower, double upper})? controlRange,
});

/// A snapshot identifying a body in the compiled model.
class const MjBodyInfo(final int id, final String name);
