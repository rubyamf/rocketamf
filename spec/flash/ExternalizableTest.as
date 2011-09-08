package {
	import flash.utils.*;

	public class ExternalizableTest implements IExternalizable {
		private var one:int;
		private var two:int;

		public function ExternalizableTest(one:int, two:int) {
			this.one = one;
			this.two = two;
		}

		public function writeExternal(output:IDataOutput):void {
			output.writeDouble(one);
			output.writeDouble(two);
		}

		public function readExternal(input:IDataInput):void {
			one = input.readDouble();
			two = input.readDouble();
		}
	}
}