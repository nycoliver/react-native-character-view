
using ReactNative.Bridge;
using System;
using System.Collections.Generic;
using Windows.ApplicationModel.Core;
using Windows.UI.Core;

namespace Com.Reactlibrary.RNCharacterView
{
    /// <summary>
    /// A module that allows JS to share data.
    /// </summary>
    class RNCharacterViewModule : NativeModuleBase
    {
        /// <summary>
        /// Instantiates the <see cref="RNCharacterViewModule"/>.
        /// </summary>
        internal RNCharacterViewModule()
        {

        }

        /// <summary>
        /// The name of the native module.
        /// </summary>
        public override string Name
        {
            get
            {
                return "RNCharacterView";
            }
        }
    }
}
