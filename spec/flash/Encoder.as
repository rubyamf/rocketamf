package {
	import flash.desktop.NativeApplication;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.filesystem.*;
	import flash.net.registerClassAlias;
	import flash.utils.*;
	import flash.xml.XMLDocument;
	import mx.collections.ArrayCollection;

	public class Encoder extends Sprite {
		public function Encoder() {
			var dir:File = File.userDirectory;
			dir.browseForDirectory("Select Output Directory");
			dir.addEventListener(Event.SELECT, writeSpecFixtures)
		}

		private function writeSpecFixtures(evt:Event):void {
			registerClassAlias('org.amf.ASClass', ASClass);
			registerClassAlias('ExternalizableTest', ExternalizableTest);
			registerClassAlias('flex.messaging.io.ArrayCollection', mx.collections.ArrayCollection);
			XML.prettyPrinting = false;

			var tests:Object = {
				'amf0-number': 3.5,
				'amf0-boolean': true,
				'amf0-string': "this is a テスト",
				'amf0-null': null,
				'amf0-undefined': undefined,
				'amf0-hash': function():Array {
					var a:Array = new Array();
					a['a'] = 'b';
					a['c'] = 'd';
					return a;
				},
				'amf0-ecma-ordinal-array': ['a', 'b', 'c', 'd'],
				//'amf0-strict-array': ['a', 'b', 'c', 'd'], // Not possible from AS3
				'amf0-time': function():Date {
					var d:Date = new Date();
					d.setTime(Date.UTC(2003, 1, 13, 5));
					return d;
				},
				'amf0-date': function():Date {
					var d:Date = new Date();
					d.setTime(Date.UTC(2020, 4, 30));
					return d;
				},
				'amf0-xml-doc': new XMLDocument('<parent><child prop="test"/></parent>'),
				'amf0-object': function():Object {
					var o:Object = {};
					o['bar'] = 3.14;
					o['foo'] = 'baz';
					return o;
				},
				'amf0-untyped-object': function():Object {
					var o:Object = {};
					o['baz'] = null;
					o['foo'] = 'bar';
					return o;
				},
				'amf0-typed-object': new ASClass('bar'),
				'amf0-ref-test': function():Object {
					var o:Object = tests['amf0-object']();
					var ret:Object = {};
					ret['0'] = o;
					ret['1'] = o;
					return ret;
				},
				'amf3-null': null,
				'amf3-false': false,
				'amf3-true': true,
				'amf3-max': 268435455,
				'amf3-0': 0,
				'amf3-min': -268435456,
				'amf3-float': 3.5,
				'amf3-large-max': 268435456,
				'amf3-large-min': -268435457,
				'amf3-bignum': Math.pow(2, 1000),
				'amf3-string': "String . String",
				'amf3-symbol': "foo",
				'amf3-date': function():Date {
					var d:Date = new Date();
					d.setTime(0);
					return d;
				},
				'amf3-xml': new XML('<parent><child prop="test"/></parent>'),
				'amf3-xml-doc': new XMLDocument('<parent><child prop="test"/></parent>'),
				'amf3-dynamic-object': function():Object {
					var o:Object = {};
					o['another_public_property'] = 'a_public_value';
					o['nil_property'] = null;
					o['property_one'] = 'foo';
					return o;
				},
				'amf3-typed-object': new ASClass('bar'),
				'amf3-externalizable': [new ExternalizableTest(5, 7), new ExternalizableTest(13, 5)],
				'amf3-hash': function():Object {
					var o:Object = {};
					o['answer'] = 42;
					o['foo'] = 'bar';
					return o;
				},
				'amf3-empty-array': [],
				'amf3-primitive-array': [1,2,3,4,5],
				'amf3-associative-array': function():Array {
					var a:Array = [];
					a["asdf"] = "fdsa";
					a["foo"] = "bar";
					a[42] = "bar";
					a[0] = "bar1";
					a[1] = "bar2";
					a[2] = "bar3";
					return a;
				},
				'amf3-mixed-array': function():Array {
					var h1:Object = {"foo_one": "bar_one"};
					var h2:Object = {"foo_two": ""};
					var so1:Object = {"foo_three": 42};
					return [h1, h2, so1, {}, [h1, h2, so1], [], 42, "", [], "", {}, "bar_one", so1];
				},
				'amf3-array-collection': new ArrayCollection(['foo', 'bar']),
				'amf3-complex-array-collection': function():Array {
					var a:ArrayCollection = new ArrayCollection(['foo', 'bar']);
					var b:ArrayCollection = new ArrayCollection([new ASClass('bar'), new ASClass('asdf')]);
					return [a, b, b];
				},
				'amf3-byte-array': function():ByteArray {
					var b:ByteArray = new ByteArray();
					b.writeByte(0);
					b.writeByte(3);
					b.writeUTFBytes("これtest");
					b.writeByte(64);
					return b;
				},
				'amf3-empty-dictionary': new Dictionary(),
				'amf3-dictionary': function():Dictionary {
					var d:Dictionary = new Dictionary();
					d["bar"] = "asdf1";
					d[new ASClass("baz")] = "asdf2";
					return d;
				},
				'amf3-string-ref': function():Array {
					var foo:String = "foo";
					var bar:String = "str";
					return [foo, bar, foo, bar, foo, {"str": foo}];
				},
				'amf3-empty-string-ref': function():Array {
					var s:String = "";
					return [s, s];
				},
				'amf3-date-ref': function():Array {
					var d:Date = new Date();
					d.setTime(0);
					return [d, d];
				},
				'amf3-object-ref': function():Array {
					var obj1:Object = {"foo": "bar"};
					var obj2:Object = {"foo": obj1["foo"]};
					return [[obj1, obj2], "bar", [obj1, obj2]];
				},
				'amf3-trait-ref': [new ASClass("foo"), new ASClass("bar")],
				'amf3-array-ref': function():Array {
					var a:Array = [1, 2, 3];
					var b:Array = ['a', 'b', 'c'];
					return [a, b, a, b];
				},
				'amf3-empty-array-ref': function():Array {
					var a:Array = []; var b:Array = [];
					return [a, b, a, b];
				},
				'amf3-xml-ref': function():Array {
					var x:XML = new XML('<parent><child prop="test"/></parent>');
					return [x, x];
				},
				'amf3-byte-array-ref': function():Array {
					var b:ByteArray = new ByteArray();
					b.writeUTFBytes("ASDF");
					return [b, b];
				},
				'amf3-graph-member': function():Object {
					var parentObj:Object = {};
					var child1:Object = {"children": []};
					child1['parent'] = parentObj;
					var child2:Object = {"children": []};
					child2['parent'] = parentObj;
					parentObj['children'] = [child1, child2];
					parentObj['parent'] = null;
					return parentObj;
				},
				'amf3-complex-encoded=string-array': [5, "Shift テスト", "UTF テスト", 5],
				'amf3-encoded-string-ref': ["this is a テスト", "this is a テスト"]
			};

			var outputDir:File = evt.target as File;
			for(var key:String in tests) {
				trace(key);
				var fs:FileStream = new FileStream();
				fs.objectEncoding = (key.indexOf('amf0-') === 0) ? 0 : 3;
				fs.open(outputDir.resolvePath(key+'.bin'), FileMode.WRITE);
				fs.writeObject(tests[key] is Function ? tests[key]() : tests[key]);
				fs.close();
			}

			NativeApplication.nativeApplication.exit();
		}
	}
}